defmodule Pinchflat.Utils.ChangesetUtilsTest do
  use ExUnit.Case, async: true

  defmodule MockSchema do
    use Ecto.Schema
    import Ecto.Changeset
    import Pinchflat.Utils.ChangesetUtils

    schema "mock_schemas" do
      field :title, :string
    end

    def changeset(data, attrs) do
      data
      |> cast(attrs, [:title])
      |> dynamic_default(:title, fn _ -> "default" end)
    end
  end

  describe "dynamic_default/3" do
    test "sets the default value if the field is nil" do
      changeset = MockSchema.changeset(%MockSchema{}, %{})

      assert Ecto.Changeset.get_change(changeset, :title) == "default"
    end

    test "does not set the default value if the field is not nil" do
      changeset = MockSchema.changeset(%MockSchema{}, %{title: "custom"})

      assert Ecto.Changeset.get_change(changeset, :title) == "custom"
    end
  end
end
