defmodule Pinchflat.Repo.Migrations.AddTitleRegexToSource do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :title_filter_regex, :string
    end
  end
end
