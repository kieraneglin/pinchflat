defmodule PinchflatWeb.Settings.DiagnosticsHTML do
  use PinchflatWeb, :html

  alias Pinchflat.Diagnostics.QueueDiagnostics

  embed_templates "diagnostics_html/*"

  def queue_stats do
    QueueDiagnostics.get_all_queue_stats()
  end

  def retryable_jobs do
    QueueDiagnostics.get_retryable_jobs(20)
  end

  def stuck_jobs do
    QueueDiagnostics.get_stuck_jobs(30)
  end

  def system_stats do
    QueueDiagnostics.get_system_stats()
  end

  def format_worker_name(worker) do
    worker
    |> String.split(".")
    |> Enum.at(-1)
    |> format_worker_short_name()
  end

  defp format_worker_short_name("FastIndexingWorker"), do: "Fast Indexing"
  defp format_worker_short_name("MediaDownloadWorker"), do: "Download"
  defp format_worker_short_name("MediaCollectionIndexingWorker"), do: "Indexing"
  defp format_worker_short_name("MediaQualityUpgradeWorker"), do: "Quality Upgrade"
  defp format_worker_short_name("SourceMetadataStorageWorker"), do: "Metadata"
  defp format_worker_short_name(other), do: other

  def format_queue_name(queue) do
    queue
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def format_datetime(nil), do: "-"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  def extract_last_error(errors) when is_list(errors) and length(errors) > 0 do
    errors
    |> List.last()
    |> Map.get("error", "Unknown error")
    |> String.slice(0, 200)
  end

  def extract_last_error(_), do: "No error details"

  def queue_health_class(stats) do
    cond do
      stats.paused -> "bg-yellow-500/20 border-yellow-500"
      stats.retryable > 0 -> "bg-red-500/20 border-red-500"
      stats.running >= stats.limit and stats.available > 0 -> "bg-blue-500/20 border-blue-500"
      true -> "bg-green-500/20 border-green-500"
    end
  end

  def queue_status_text(stats) do
    cond do
      stats.paused -> "Paused"
      stats.retryable > 0 -> "Has Failures"
      stats.running >= stats.limit -> "At Capacity"
      stats.running > 0 -> "Active"
      true -> "Idle"
    end
  end
end
