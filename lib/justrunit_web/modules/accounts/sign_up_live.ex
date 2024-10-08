defmodule JustrunitWeb.Modules.Accounts.SignUpLive do
  use JustrunitWeb, :live_view
  import JustrunitWeb.CoreComponents, only: [input: 1]

  def render(assigns) do
    ~H"""
    <div class="mx-auto mt-48 w-96 rounded-xl">
      <h1 class="text-2xl font-bold text-center">New Account</h1>
      <p class="py-2 text-center">
        Click
        <.link navigate={~p"/sign-in"} class="text-lg text-blue-500 hover:underline">here</.link>
        to sign in
      </p>
      <%= if @check_errors do %>
        <div class="p-2 text-white bg-red-500 rounded-lg">
          <%= @form.errors %>
        </div>
      <% end %>
      <.form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        action={~p"/sign-in?_action=registered"}
        phx-trigger-action={@trigger_submit}
        method="post"
        class="space-y-10"
      >
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          class="p-2 w-full rounded-lg border-2 border-blue-500"
        />
        <.input
          field={@form[:password]}
          label="Password"
          type="password"
          class="p-2 w-full rounded-lg border-2 border-blue-500"
        />
        <button
          type="submit"
          class="px-4 py-2 w-full font-semibold text-white bg-blue-500 rounded-lg transition hover:bg-blue-600"
        >
          Register
        </button>
      </.form>
    </div>
    """
  end

  alias JustrunitWeb.Modules.Accounts.User
  alias JustrunitWeb.Modules.Accounts
  alias JustrunitWeb.Modules.Plans.UserPlan
  alias JustrunitWeb.Modules.Plans.Plan
  alias JustrunitWeb.Modules.Rap.Role
  alias Justrunit.Repo

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, layout: false, temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    users_count = Repo.aggregate(User, :count, :id)

    role = Repo.get_by(Role, name: "User")

    default_plan = Repo.get_by(Plan, description: "default")

    user_params =
      user_params
      |> Map.put("name", "User" <> "#{users_count + 1}")
      |> Map.put("handle", "user" <> "#{users_count + 1}")
      |> Map.put("plan_id", default_plan.id)
      |> Map.put("role_id", role.id)

    result = User.registration_changeset(%User{}, user_params) |> Repo.insert()

    case result do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
