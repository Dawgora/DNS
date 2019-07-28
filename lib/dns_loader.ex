defmodule DNS.Loader do
  use GenServer

    def start_link(_config) do
      GenServer.start_link(__MODULE__, [], name: :zone_loader)
    end

    def init(_args) do
      {:ok, json} = load_zonefile()
      {:ok, json}
    end

    def get_data(data) do
      GenServer.call(:zone_loader, {:data, data})
    end

    def handle_call({:data, data}, _pid, state) do
      {:reply, {:ok, state[data]} ,state}
    end

    defp load_zonefile(zonefile \\ "zonefile/zonefile.json") do
      with {:ok, body} <- File.read(zonefile),
           {:ok, json} <- Poison.decode(body), do: {:ok, json}
    end
end
