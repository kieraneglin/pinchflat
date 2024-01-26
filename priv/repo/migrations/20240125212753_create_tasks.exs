defmodule Pinchflat.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :job_id, references(:oban_jobs, on_delete: :delete_all), null: false
      # `restrict` because we need to be sure to delete pending tasks when a channel is deleted
      add :channel_id, references(:channels, on_delete: :restrict), null: true

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:job_id])
    create index(:tasks, [:channel_id])
  end
end
