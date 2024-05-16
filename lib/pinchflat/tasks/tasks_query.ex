defmodule Pinchflat.Tasks.TasksQuery do
  @moduledoc """
  Query helpers for the Tasks context.

  These methods are made to be one-ish liners used
  to compose queries. Each method should strive to do
  _one_ thing. These don't need to be tested as
  they are just building blocks for other functionality
  which, itself, will be tested.
  """
  import Ecto.Query, warn: false

  alias Pinchflat.Tasks.Task

  # This allows the module to be aliased and query methods to be used
  # all in one go
  # usage: use Pinchflat.Tasks.TasksQuery
  defmacro __using__(_opts) do
    quote do
      import Ecto.Query, warn: false

      alias unquote(__MODULE__)
    end
  end

  def new do
    Task
  end

  def join_job(query) do
    join(query, :inner, [t], j in assoc(t, :job))
  end

  def in_state(states) when is_list(states) do
    dynamic([t, j], j.state in ^states)
  end

  def in_state(state), do: in_state([state])

  def has_worker(worker_name) do
    dynamic([t, j], fragment("? LIKE ?", j.worker, ^"%.#{worker_name}"))
  end
end
