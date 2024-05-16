defmodule Pinchflat.Pages.JobTableLive do
  use PinchflatWeb, :live_view
  use Pinchflat.Tasks.TasksQuery

  alias Pinchflat.Repo
  # alias Pinchflat.Utils.NumberUtils
  alias PinchflatWeb.CustomComponents.TextComponents

  def render(%{tasks: []} = assigns) do
    ~H"""
    <div class="mb-4 flex items-center">
      <p class="ml-2">Nothing Here!</p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="max-w-full overflow-x-auto">
        <.table rows={@tasks} table_class="text-white">
          <:col :let={task} label="Job ID">
            <%= task.job_id %>
          </:col>
        </.table>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    tasks = get_tasks()

    {:ok, assign(socket, tasks: tasks)}
  end

  defp get_tasks do
    TasksQuery.new()
    |> TasksQuery.join_job()
    |> where(^TasksQuery.in_state("completed"))
    |> limit(5)
    |> Repo.all()
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(datetime) do
    TextComponents.datetime_in_zone(%{datetime: datetime, format: "%Y-%m-%d %H:%M"})
  end
end
