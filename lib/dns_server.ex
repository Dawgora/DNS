defmodule DNS.DNSServer do
  use GenServer

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(port \\ 53) do
    GenServer.start_link(__MODULE__, port)
  end

  def init(port) do
    :gen_udp.open(port, [:binary, active: true])
  end

  def handle_info({:udp, _socket, address, port, data}, socket) do
    handle_packet(data, socket, address, port)
  end

  defp handle_packet("quit \n", socket, _address, _port) do
    IO.puts("quit \n")
    :gen_udp.close(socket)
    {:stop, :normal, nil}
  end

  defp handle_packet(packet, socket, address, port) do
    {:ok, response} = build_response(packet)
    IO.inspect response
    :gen_udp.send(socket, address, port, response)
    {:noreply, socket}
  end

  @spec build_response(binary()) :: {:ok, <<_::16>>}
  defp build_response(<<_transactionId::bits-size(16), flags::bits-size(16), _data::binary>> = _packet) do
    << _qr::bits-size(1), opcode::bits-size(4), _aa::bits-size(1), _tc::bits-size(1), _rd::bits-size(1), _flag2::8>> = flags
    qr = <<1::1>>
    aa = <<1::1>>
    tc = <<0::1>>
    rd = <<0::1>>
    ra = <<0::1>>
    z = <<0::3>>
    rcode = <<0::4>>

    {:ok, <<qr::bits, opcode::bits, aa::bits, tc::bits, rd::bits, ra::bits, z::bits, rcode::bits>>}
  end
end
