defmodule DNS.DNSServer do
  use GenServer, Bitwise

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
    IO.inspect(:erlang.iolist_to_binary(packet))
    build_response(packet)
    :gen_udp.send(socket, address, port, 'Hello world')
    {:noreply, socket}
  end

  defp build_response(<<transactionId::size(16), flags::size(16), _data::binary>> = _packet) do
    <<flag_byte1::8, flag_byte2::8>> = <<flags::16>>
    IO.inspect(transactionId)
    IO.inspect(flag_byte1)
    IO.inspect(flag_byte2)

    <<qr::1, opcode::5, tc::1, rd::1>> = <<flag_byte1::8>>
    aa = <<1::1>>

    ra = <<0::1>>
    z = <<0::3>>
    rcode = <<0::4>>

    response_flag =
      <<qr::bitstring, opcode::bitstring, aa::bitstring, tc::bitstring, rd::bitstring,
        ra::bitstring, z::bitstring, rcode::bitstring>>
  end
end