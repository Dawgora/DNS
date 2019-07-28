defmodule DNS do
  @moduledoc """
  Documentation for DNS.
  """

  def start_server do
    {:ok, _pid} = Supervisor.start_link([{DNS.DNSServer, 53}], strategy: :one_for_one)
    {:ok, _pid} = Supervisor.start_link([{DNS.Loader, []}], strategy: :one_for_one)
  end
end
