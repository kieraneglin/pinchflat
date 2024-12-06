defmodule Pinchflat.Pages.JobTableLive do
  use PinchflatWeb, :live_view
  use Pinchflat.Tasks.TasksQuery

  alias Pinchflat.Repo
  alias Pinchflat.Tasks.Task
  alias PinchflatWeb.CustomComponents.TextComponents

  def render(%{tasks: []} = assigns) do
    ~H"""
    <div class="mb-4 flex items-center">
      <p>Nothing Here!</p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-full overflow-x-auto">
      <.table rows={@tasks} table_class="text-white">
        <:col :let={task} label="Task">
          {worker_to_task_name(task.job.worker)}
        </:col>
        <:col :let={task} label="Subject">
          <.subtle_link href={task_to_link(task)}>
            {StringUtils.truncate(task_to_record_name(task), 35)}
          </.subtle_link>
        </:col>
        <:col :let={task} label="Attempt No.">
          {task.job.attempt}
        </:col>
        <:col :let={task} label="Started At">
          {format_datetime(task.job.attempted_at)}
        </:col>
      </.table>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    PinchflatWeb.Endpoint.subscribe("job:state")

    {:ok, assign(socket, tasks: get_tasks())}
  end

  def handle_info(%{topic: "job:state", event: "change"}, socket) do
    {:noreply, assign(socket, tasks: get_tasks())}
  end

  defp get_tasks do
    TasksQuery.new()
    |> TasksQuery.join_job()
    |> where(^TasksQuery.in_state("executing"))
    |> where(^TasksQuery.has_tag("show_in_dashboard"))
    |> order_by([t, j], desc: j.attempted_at)
    |> Repo.all()
    |> Repo.preload([:media_item, :source])
  end

  defp worker_to_task_name(worker) do
    final_module_part =
      worker
      |> String.split(".")
      |> Enum.at(-1)

    map_worker_to_task_name(final_module_part)
  end

  defp map_worker_to_task_name("FastIndexingWorker"), do: "Fast Indexing Source"
  defp map_worker_to_task_name("MediaDownloadWorker"), do: "Downloading Media"
  defp map_worker_to_task_name("MediaCollectionIndexingWorker"), do: "Indexing Source"
  defp map_worker_to_task_name("MediaQualityUpgradeWorker"), do: "Upgrading Media Quality"
  defp map_worker_to_task_name("SourceMetadataStorageWorker"), do: "Fetching Source Metadata"
  defp map_worker_to_task_name(other), do: other <> " (Report to Devs)"

  defp task_to_record_name(%Task{} = task) do
    case task do
      %Task{source: source} when source != nil -> source.custom_name
      %Task{media_item: mi} when mi != nil -> mi.title
      _ -> "Unknown Record"
    end
  end

  defp task_to_link(%Task{} = task) do
    case task do
      %Task{source: source} when source != nil -> ~p"/sources/#{source.id}"
      %Task{media_item: mi} when mi != nil -> ~p"/sources/#{mi.source_id}/media/#{mi}"
      _ -> "#"
    end
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(datetime) do
    TextComponents.datetime_in_zone(%{datetime: datetime, format: "%Y-%m-%d %H:%M"})
  end
end
