# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Files.Queries do
  import Ecto.Query

  alias Bonfire.Files.Media

  def query(Media), do: from(c in Media, as: :content)
  def query(filters), do: filter(Media, filters)

  def query(q, filters), do: filter(query(q), filters)

  @doc "Filter the query according to arbitrary criteria"
  def filter(query, filter_or_filters)

  def filter(q, filters) when is_list(filters), do: Enum.reduce(filters, q, &filter(&2, &1))

  def filter(q, {:deleted, nil}), do: where(q, [content: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, :not_nil}), do: where(q, [content: c], not is_nil(c.deleted_at))
  def filter(q, {:deleted, false}), do: where(q, [content: c], is_nil(c.deleted_at))
  def filter(q, {:deleted, true}), do: where(q, [content: c], not is_nil(c.deleted_at))

  def filter(q, {:deleted, {:gte, %DateTime{} = time}}),
    do: where(q, [content: c], c.deleted_at >= ^time)

  def filter(q, {:deleted, {:lte, %DateTime{} = time}}),
    do: where(q, [content: c], c.deleted_at <= ^time)

  def filter(q, {:published, nil}), do: where(q, [content: c], is_nil(c.published_at))
  def filter(q, {:published, :not_nil}), do: where(q, [content: c], not is_nil(c.published_at))
  def filter(q, {:published, false}), do: where(q, [content: c], is_nil(c.published_at))
  def filter(q, {:published, true}), do: where(q, [content: c], not is_nil(c.published_at))

  # by field values

  def filter(q, {:id, id}) when is_binary(id), do: where(q, [content: c], c.id == ^id)
  def filter(q, {:id, ids}) when is_list(ids), do: where(q, [content: c], c.id in ^ids)

  def filter(q, {:user, id}) when is_binary(id),
    do: where(q, [content: c], c.user_id == ^id)

  def filter(q, {:user, ids}) when is_list(ids),
    do: where(q, [content: c], c.user_id in ^ids)
end
