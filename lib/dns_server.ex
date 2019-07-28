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
    :gen_udp.send(socket, address, port, response)
    {:noreply, socket}
  end

  @spec build_response(binary()) :: {:ok, binary()}
  defp build_response(
         <<transactionID::binary-size(2), flags::binary-size(2), _qdcount::binary-size(2),
           _ancount::binary-size(2), _nscount::binary-size(2), _arcount::binary-size(2),
           data::binary>> = _packet
       ) do
    <<_qr::bits-size(1), opcode::bits-size(4), _aa::bits-size(1), _tc::bits-size(1),
      _rd::bits-size(1), _flag2::binary-size(1)>> = flags

    qr = <<1::1>>
    aa = <<1::1>>
    tc = <<0::1>>
    rd = <<0::1>>
    ra = <<0::1>>
    z = <<0::3>>
    rcode = <<0::4>>

    returnFlags =
      <<qr::bits, opcode::bits, aa::bits, tc::bits, rd::bits, ra::bits, z::bits, rcode::bits>>

    #  question count
    qdcount = <<0, 1>>

    {:ok, {domain_list, rest}} = get_question_domain(data)
    <<type::binary-size(2), class::binary-size(2), _rest2::binary>> = rest

    {:ok, typeName} = get_type_name(type)
    {:ok, _className} = get_class_name(class)

    # Answer count, must be 2 bytes, big endian
    {:ok, typeData} = GenServer.call(:zone_loader, {:data, typeName})
    ancount = typeData |> Enum.count()

    # nameserver count
    {:ok, nsData} = GenServer.call(:zone_loader, {:data, "ns"})
    nscount = nsData |> Enum.count()
    # additional count
    arcount = <<0, 0>>

    header =
      <<transactionID::bits, returnFlags::bits, qdcount::bits, ancount::16, nscount::16,
        arcount::bits>>

    {:ok, dns_body} = create_body({domain_list, type, class})

    {:ok, <<header::bits, dns_body::bits>>}
  end

  defp get_question_domain(data) do
    get_domain(data)
  end

  defp get_domain(data) do
    {:ok, response} = get_domain(data, [])

    {:ok, response}
  end

  defp get_domain(<<0, rest::binary>> = _data, parts) do
    {:ok, {parts, rest}}
  end

  defp get_domain(<<length::8, name::binary-size(length), rest::binary>> = _data, parts) do
    get_domain(rest, parts ++ [name])
  end

  defp get_type_name(type) do
    case type do
      <<0, 1>> -> {:ok, "a"}
      _ -> {:error, "No type found"}
    end
  end

  defp get_class_name(class) do
    case class do
      <<0, 1>> -> {:ok, "in"}
      _ -> {:error, "No class found"}
    end
  end

  defp create_body({domain, type, class}) do
    {:ok, domainname} = convert_domainname(domain, <<>>)
    response = <<domainname::bitstring, type::bits, class::bits>>
    {:ok, records} = records_to_bytes({domain, type, class})

    {:ok, <<response::bits, records::bits>>}
  end

  defp convert_domainname([], response) do
    {:ok, <<response::bits, 0>>}
  end

  defp convert_domainname([head | tail], bits) do
    length = String.length(head)
    response = <<bits::bits, length, head::bitstring>>
    convert_domainname(tail, response)
  end

  defp records_to_bytes({_domain, type, class}) do
    {:ok, typeName} = get_type_name(type)
    {:ok, records} = GenServer.call(:zone_loader, {:data, typeName})
    transform_answers(records, << <<192, 12>>, type::bits, class::bits>>, <<>>)
  end

  defp transform_answers([], _answer_start, answers) do
    {:ok, answers}
  end

  defp transform_answers([record | records] , answer_start, answers) do
    ttl = <<record["ttl"]::8*4>>
    {:ok, {ip1, ip2, ip3, ip4}} = :inet.parse_address(to_charlist(record["value"]))
    updated_answers = << answers::bits, answer_start::bits, ttl::bits, <<0,4 >>,  <<ip1, ip2, ip3, ip4>> >>

    transform_answers(records, answer_start, updated_answers)
  end
end
