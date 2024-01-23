defmodule Pinchflat.ProfilesTest do
  use Pinchflat.DataCase

  alias Pinchflat.Profiles

  describe "media_profiles" do
    alias Pinchflat.Profiles.MediaProfile

    import Pinchflat.ProfilesFixtures

    @invalid_attrs %{name: nil, output_path_template: nil}

    test "list_media_profiles/0 returns all media_profiles" do
      media_profile = media_profile_fixture()
      assert Profiles.list_media_profiles() == [media_profile]
    end

    test "get_media_profile!/1 returns the media_profile with given id" do
      media_profile = media_profile_fixture()
      assert Profiles.get_media_profile!(media_profile.id) == media_profile
    end

    test "create_media_profile/1 with valid data creates a media_profile" do
      valid_attrs = %{name: "some name", output_path_template: "some output_path_template"}

      assert {:ok, %MediaProfile{} = media_profile} = Profiles.create_media_profile(valid_attrs)
      assert media_profile.name == "some name"
      assert media_profile.output_path_template == "some output_path_template"
    end

    test "create_media_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_media_profile(@invalid_attrs)
    end

    test "update_media_profile/2 with valid data updates the media_profile" do
      media_profile = media_profile_fixture()

      update_attrs = %{
        name: "some updated name",
        output_path_template: "some updated output_path_template"
      }

      assert {:ok, %MediaProfile{} = media_profile} =
               Profiles.update_media_profile(media_profile, update_attrs)

      assert media_profile.name == "some updated name"
      assert media_profile.output_path_template == "some updated output_path_template"
    end

    test "update_media_profile/2 with invalid data returns error changeset" do
      media_profile = media_profile_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Profiles.update_media_profile(media_profile, @invalid_attrs)

      assert media_profile == Profiles.get_media_profile!(media_profile.id)
    end

    test "delete_media_profile/1 deletes the media_profile" do
      media_profile = media_profile_fixture()
      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile)
      assert_raise Ecto.NoResultsError, fn -> Profiles.get_media_profile!(media_profile.id) end
    end

    test "change_media_profile/1 returns a media_profile changeset" do
      media_profile = media_profile_fixture()
      assert %Ecto.Changeset{} = Profiles.change_media_profile(media_profile)
    end
  end
end
