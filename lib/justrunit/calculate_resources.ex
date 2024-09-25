defmodule Justrunit.CalculateRam do
  @moduledoc """
      Calculates max. amount of CPU and RAM cloud hypervisor container can use and assigns it to a environmental variable every second.
  """

  @second 1_000
  @max_usage 0.8

  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)

  @impl true
  def init(:ok), do: schedule_update() && {:ok, %{}}

  @impl true
  def handle_info(:update, state) do
    update_max_resources()
    schedule_update()
    {:noreply, state}
  end

  defp schedule_update, do: Process.send_after(self(), :update, @second)

  defp update_max_resources do
    max_cpu = round(:erlang.system_info(:logical_processors) * @max_usage)
    max_ram = round(:erlang.memory(:total) * @max_usage)

    System.put_env("MAX_RAM", Integer.to_string(max_cpu))
    System.put_env("MAX_RAM", Integer.to_string(max_ram))

    IO.puts("Updated MAX_RAM to #{max_cpu} bytes")
    IO.puts("Updated MAX_RAM to #{max_ram} bytes")
  end
end