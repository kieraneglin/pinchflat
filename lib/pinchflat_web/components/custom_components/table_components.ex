defmodule PinchflatWeb.CustomComponents.TableComponents do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Renders a table component with the given rows and columns.

  ## Examples

      <.table rows={@users}>
        <:col :let={user} label="Name"><%= user.name %></:col>
      </.table>
  """
  attr :rows, :list, required: true
  attr :table_class, :string, default: ""

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  def table(assigns) do
    ~H"""
    <table class={["w-full table-auto", @table_class]}>
      <thead>
        <tr class="bg-gray-2 text-left dark:bg-meta-4">
          <th :for={col <- @col} class="px-4 py-4 font-medium text-black dark:text-white xl:pl-11">
            <%= col[:label] %>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr :for={{row, i} <- Enum.with_index(@rows)}>
          <td
            :for={col <- @col}
            class={[
              "px-4 py-5 pl-9 dark:border-strokedark xl:pl-11",
              i + 1 > length(@rows) && "border-b border-[#eee] dark:border-π",
              col[:class]
            ]}
          >
            <%= render_slot(col, @row_item.(row)) %>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end
end
