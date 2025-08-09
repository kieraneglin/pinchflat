defmodule Pinchflat.Repo.Migrations.AddMembersContentBehaviourToSource do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :members_content_behaviour, :string, null: false, default: "include"
    end
  end
end
