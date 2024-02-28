defmodule Pinchflat.ProfilesTest do
  use Pinchflat.DataCase

  import Pinchflat.MediaFixtures
  import Pinchflat.SourcesFixtures
  import Pinchflat.ProfilesFixtures

  alias Pinchflat.Profiles
  alias Pinchflat.Profiles.MediaProfile

  @invalid_attrs %{name: nil, output_path_template: nil}

  describe "list_media_profiles/0" do
    test "it returns all media_profiles" do
      media_profile = media_profile_fixture()
      assert Profiles.list_media_profiles() == [media_profile]
    end
  end

  describe "get_media_profile!/1" do
    test "it returns the media_profile with given id" do
      media_profile = media_profile_fixture()
      assert Profiles.get_media_profile!(media_profile.id) == media_profile
    end
  end

  describe "create_media_profile/1" do
    test "creation with valid data creates a media_profile" do
      valid_attrs = %{name: "some name", output_path_template: "some output_path_template"}

      assert {:ok, %MediaProfile{} = media_profile} = Profiles.create_media_profile(valid_attrs)
      assert media_profile.name == "some name"
      assert media_profile.output_path_template == "some output_path_template"
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_media_profile(@invalid_attrs)
    end
  end

  describe "update_media_profile/2" do
    test "updating with valid data updates the media_profile" do
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

    test "updating with invalid data returns error changeset" do
      media_profile = media_profile_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Profiles.update_media_profile(media_profile, @invalid_attrs)

      assert media_profile == Profiles.get_media_profile!(media_profile.id)
    end
  end

  describe "delete_media_profile/2" do
    test "deletion deletes the media_profile" do
      media_profile = media_profile_fixture()

      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_profile) end
    end

    test "deletion deletes all sources" do
      media_profile = media_profile_fixture()
      source = source_fixture(media_profile_id: media_profile.id)

      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
    end

    test "deletion deletes all media items" do
      media_profile = media_profile_fixture()
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_fixture(source_id: source.id)

      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "deletion does not delete files by default" do
      media_profile = media_profile_fixture()
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_with_attachments(%{source_id: source.id})

      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile)

      assert File.exists?(media_item.media_filepath)
    end
  end

  describe "delete_media_profile/2 when deleting files" do
    test "still deletes all the needful records" do
      media_profile = media_profile_fixture()
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_fixture(source_id: source.id)

      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile, delete_files: true)

      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_profile) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(source) end
      assert_raise Ecto.NoResultsError, fn -> Repo.reload!(media_item) end
    end

    test "deletes files" do
      media_profile = media_profile_fixture()
      source = source_fixture(media_profile_id: media_profile.id)
      media_item = media_item_with_attachments(%{source_id: source.id})

      assert {:ok, %MediaProfile{}} = Profiles.delete_media_profile(media_profile, delete_files: true)

      refute File.exists?(media_item.media_filepath)
    end
  end

  describe "change_media_profile/1" do
    test "it returns a media_profile changeset" do
      media_profile = media_profile_fixture()
      assert %Ecto.Changeset{} = Profiles.change_media_profile(media_profile)
    end
  end
end
