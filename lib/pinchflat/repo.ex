defmodule Pinchflat.Repo do
  use Ecto.Repo,
    otp_app: :pinchflat,
    adapter: Ecto.Adapters.SQLite3

  import Ecto.Query, warn: false

  @doc """
  It's not immediately obvious if an Oban job qualifies as unique, so this method
  attempts creating a job and checks for the `conflict?` field in the returned job.

  Returns {:ok, %Oban.Job{}} | {:duplicate, %Oban.Job{}} | {:error, any()}.
  """
  def insert_unique_job(job_struct) do
    case Oban.insert(job_struct) do
      {:ok, %Oban.Job{conflict?: false} = job} -> {:ok, job}
      {:ok, %Oban.Job{conflict?: true} = job} -> {:duplicate, job}
      err -> err
    end
  end

  @doc """
  Applies a limit to a query if provided, otherwise returns the query as-is.

  Returns %Ecto.Query{}.
  """
  def maybe_limit(query, limit) do
    if limit, do: limit(query, ^limit), else: query
  end
end
