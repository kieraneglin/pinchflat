defmodule Pinchflat.Repo.Migrations.AddOutputTemplateToSources do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :output_path_template_override, :string
    end
  end
end
