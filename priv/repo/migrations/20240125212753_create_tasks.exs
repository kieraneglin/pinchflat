defmodule Pinchflat.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :job_id, references(:oban_jobs, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all), null: true

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:job_id])
    create index(:tasks, [:channel_id])
  end
end
