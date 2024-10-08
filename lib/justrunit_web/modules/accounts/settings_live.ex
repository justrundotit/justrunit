defmodule JustrunitWeb.Modules.Accounts.SettingsLive do
  use JustrunitWeb, :live_view
  import JustrunitWeb.BreadcrumbComponent, only: [breadcrumb: 1]

  @seconds_in_hour 3600
  @seconds_in_minute 60

  def render(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-submit="save"
      phx-change="validate"
      class="flex flex-col gap-8 mx-auto my-12 max-w-sm lg:max-w-2xl"
    >
      <.breadcrumb items={[%{label: "justboxes", navigate: "/justboxes/"}, %{text: "Settings"}]} />
      <h1 class="text-2xl font-bold text-center">Account details</h1>
      <a href={@handle} class="mx-auto text-blue-500 hover:underline">View Profile</a>
      <div class="space-y-2">
        <label class="text-sm font-semibold">Profile Image</label>
        <div class="flex justify-center items-center p-4 w-full h-12 bg-gray-100 rounded-md border border-gray-300">
          <.live_file_input
            upload={@uploads.profile}
            class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 hover:file:bg-blue-200 hover:file:cursor-pointer"
          />
        </div>
      </div>
      <.input field={@form[:name]} label="Name" type="text" class="w-full" />
      <.input field={@form[:handle]} label="Handle" type="text" class="w-full" />
      <.input field={@form[:bio]} label="Bio" type="textarea" class="w-full" />
      <.button type="submit" class="mt-4 lg:w-24 lg:ml-auto">Update</.button>
      <section class="flex flex-col gap-8">
        <h2 class="text-xl font-bold text-center">Rented resources</h2>
        <div class="flex">
          <div class="flex flex-col items-center w-1/4 text-center">
            <label class="text-sm text-zinc-500">Computing <%= @time_unit %></label>
            <p class="text-2xl font-bold">
              <%= @remaining_computing_time %> / <%= @computing_time_limit %>
            </p>
            <p class="text-xs text-zinc-500">
              <%= @remaining_computing_seconds %> / <%= @computing_seconds_limit %> sec
            </p>
          </div>
          <div class="w-px bg-gray-300"></div>
          <div class="flex flex-col items-center w-1/4 text-center">
            <label class="text-sm text-zinc-500">vCPUs</label>
            <p class="text-2xl font-bold"><%= @vcpus %></p>
          </div>
          <div class="w-px bg-gray-300"></div>
          <div class="flex flex-col items-center w-1/4 text-center">
            <label class="text-sm text-zinc-500">RAM</label>
            <p class="text-2xl font-bold"><%= @ram %> GBs</p>
          </div>
          <div class="w-px bg-gray-300"></div>
          <div class="flex flex-col items-center w-1/4 text-center">
            <label class="text-sm text-zinc-500">Storage</label>
            <p class="text-2xl font-bold"><%= @storage %> GBs</p>
          </div>
        </div>
        <p class="mx-auto">
          Plan:
          <span class="font-bold">
            <%= if @paid do %>
              Paid
            <% else %>
              Free
            <% end %>
          </span>
        </p>
        <.link class="mx-auto text-blue-500 hover:underline" href={~p"/settings/change-allowance"}>
          Change allowance
        </.link>
        <.input type="checkbox" field={@form[:auto_renew]} label="Auto-renew" class="w-full" />
        <.button type="submit" class="mt-4 lg:w-24 lg:ml-auto">Update</.button>
      </section>
    </.form>
    """
  end

  alias JustrunitWeb.Modules.Accounts.User
  alias JustrunitWeb.Modules.Accounts.ProfileS3
  alias Justrunit.Repo

  def mount(_, _session, socket) do
    user =
      Repo.get_by(User, id: socket.assigns.current_user.id)
      |> Repo.preload(:plan)

    form = to_form(User.settings_changeset(user, %{}))

    socket =
      assign(socket,
        form: form,
        vcpus: user.plan.vcpus,
        ram: user.plan.ram,
        storage: user.plan.storage,
        paid: user.plan.paid,
        remaining_computing_time:
          calculate_computing_time(
            user.plan.remaining_computing_seconds
            |> Decimal.to_integer()
          ),
        computing_time_seconds: 1,
        computing_time_limit: user.plan.computing_seconds_limit |> Decimal.to_integer(),
        time_unit: time_unit(user.plan.remaining_computing_seconds |> Decimal.to_integer()),
        remaining_computing_seconds:
          user.plan.remaining_computing_seconds |> Decimal.to_integer(),
        computing_seconds_limit: user.plan.computing_seconds_limit |> Decimal.to_integer(),
        handle: user.handle
      )
      |> allow_upload(:profile,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 3_000_000
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile, ref)}
  end

  defp calculate_computing_time(seconds) when seconds < @seconds_in_minute, do: "<1"
  defp calculate_computing_time(seconds) when seconds > @seconds_in_hour, do: div(seconds, 3600)

  defp time_unit(seconds) when seconds >= @seconds_in_hour, do: "Hours"
  defp time_unit(seconds) when seconds < @seconds_in_hour, do: "Minutes"

  def handle_event("validate", %{"user" => user_params}, socket) do
    user = Repo.get!(User, socket.assigns.current_user.id)
    changeset = User.settings_changeset(user, user_params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user = Repo.get!(User, socket.assigns.current_user.id)
    changeset = User.settings_changeset(user, user_params)

    consume_uploaded_entries(socket, :profile, fn %{path: path}, entry ->
      ProfileS3.put_object(socket.assigns.current_user.id, File.read!(path))
    end)

    case Repo.update(changeset) do
      {:ok, _user} ->
        socket = socket |> put_flash(:info, "Settings updated")
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
