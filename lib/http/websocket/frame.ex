defmodule PixelCanvas.WebSocket.Frame do
  import Bitwise

  defstruct [:fin, :rsv, :opcode, :mask, :masking_key, :payload_len, :payload]

  def parse(data) when is_binary(data) do
    with <<fin::1, rsv::3, opcode::4, mask::1, payload_len::integer-7, rest::binary>> <- data,
         {1, :mask} <- {mask, :mask},
         {payload_len, masking_key, rest} <- extract_masking_key(payload_len, rest),
         <<encoded_payload::binary-size(payload_len), rest::binary>> <- rest,
         {payload_data, rest} <- {decode_payload(encoded_payload, masking_key), rest} do
      {%__MODULE__{
         fin: fin,
         rsv: rsv,
         opcode: opcode,
         mask: mask,
         payload_len: payload_len,
         masking_key: masking_key,
         payload: payload_data
       }, rest}
    else
      {0, :mask} ->
        {:error, :nomask}

      _ ->
        :fragment
    end
  end

  def extract_masking_key(payload_len, rest) do
    data_size = byte_size(rest)

    cond do
      payload_len < 126 && data_size >= 4 ->
        <<masking_key::binary-4, rest::binary>> = rest
        {payload_len, masking_key, rest}

      payload_len == 126 && data_size >= 6 ->
        <<payload_len::unsigned-16, masking_key::binary-4, rest::binary>> = rest
        {payload_len, masking_key, rest}

      payload_len == 127 && data_size >= 12 ->
        <<payload_len::unsigned-64, masking_key::binary-4, rest::binary>> = rest
        {payload_len, masking_key, rest}

      true ->
        :fragment
    end
  end

  def decode_payload(data, mask) when is_binary(mask) and is_binary(data) do
    data_len = byte_size(data)
    remainder_bytes = rem(data_len, 4)

    mask_fitted_chunks =
      for <<chunk::integer-32 <- data>>, into: <<>> do
        <<mask_chunk::integer-32, _::binary>> = mask
        <<bxor(chunk, mask_chunk)::integer-32>>
      end

    case remainder_bytes do
      0 ->
        mask_fitted_chunks

      n ->
        remainder_bits = n * 8

        <<_::binary-size(data_len - n), unmasked_remainder::integer-size(remainder_bits)>> =
          data

        <<remainder_mask::integer-size(remainder_bits), _::binary>> = mask

        mask_fitted_chunks <>
          <<bxor(unmasked_remainder, remainder_mask)::integer-size(remainder_bits)>>
    end
  end
end
