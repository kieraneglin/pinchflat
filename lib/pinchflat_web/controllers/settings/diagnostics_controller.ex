defmodule PinchflatWeb.Settings.DiagnosticsController do
  use PinchflatWeb, :controller

  alias Pinchflat.Diagnostics.QueueDiagnostics

  def show(conn, _params) do
    render(conn, "show.html")
  end

  def reset_stuck_jobs(conn, _params) do
    count = QueueDiagnostics.reset_stuck_jobs()

    conn
    |> put_flash(:info, "Reset #{count} stuck job(s). The queue will restart processing shortly.")
    |> redirect(to: ~p"/diagnostics")
  end

  def reset_retryable_jobs(conn, _params) do
    count = QueueDiagnostics.reset_retryable_jobs()

    conn
    |> put_flash(:info, "Reset #{count} retryable job(s). They will be retried shortly.")
    |> redirect(to: ~p"/diagnostics")
  end

  def reset_job(conn, %{"id" => job_id}) do
    case QueueDiagnostics.reset_job(String.to_integer(job_id)) do
      1 ->
        conn
        |> put_flash(:info, "Job ##{job_id} has been reset and will retry shortly.")
        |> redirect(to: ~p"/diagnostics")

      0 ->
        conn
        |> put_flash(:error, "Job ##{job_id} could not be reset. It may have already completed or been cancelled.")
        |> redirect(to: ~p"/diagnostics")
    end
  end

  def cancel_job(conn, %{"id" => job_id}) do
    case QueueDiagnostics.cancel_job(String.to_integer(job_id)) do
      {:ok, :cancelled} ->
        conn
        |> put_flash(:info, "Job ##{job_id} has been cancelled.")
        |> redirect(to: ~p"/diagnostics")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Job ##{job_id} could not be cancelled.")
        |> redirect(to: ~p"/diagnostics")
    end
  end
end
