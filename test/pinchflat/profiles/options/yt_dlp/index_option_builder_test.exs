defmodule Pinchflat.Profiles.Options.YtDlp.IndexOptionBuilderTest do
  use ExUnit.Case, async: true

  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Profiles.Options.YtDlp.IndexOptionBuilder

  @media_profile %MediaProfile{
    output_path_template: "{{ title }}.%(ext)s",
    shorts_behaviour: :include,
    livestream_behaviour: :include
  }

  describe "build/1 when testing release type options" do
    test "adds correct filter when shorts_behaviour is :only" do
      media_profile = %MediaProfile{@media_profile | shorts_behaviour: :only}

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "original_url*=/shorts/"} in res
      refute {:match_filter, "original_url!*=/shorts/"} in res
      refute {:match_filter, "!was_live"} in res
      refute {:match_filter, "was_live"} in res
    end

    test "adds correct filter when livestream_behaviour is :only" do
      media_profile = %MediaProfile{@media_profile | livestream_behaviour: :only}

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "was_live"} in res
      refute {:match_filter, "!was_live"} in res
      refute {:match_filter, "!original_url*=/shorts/"} in res
      refute {:match_filter, "original_url*=/shorts/"} in res
    end

    test "adds correct filter when both livestreams and shorts are :only" do
      media_profile = %MediaProfile{
        @media_profile
        | shorts_behaviour: :only,
          livestream_behaviour: :only
      }

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "original_url*=/shorts/"} in res
      assert {:match_filter, "was_live"} in res
      refute {:match_filter, "original_url!*=/shorts/"} in res
      refute {:match_filter, "!was_live"} in res
    end

    test "adds correct filter when shorts_behaviour is :exclude" do
      media_profile = %MediaProfile{@media_profile | shorts_behaviour: :exclude}

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "original_url!*=/shorts/"} in res
      refute {:match_filter, "original_url*=/shorts/"} in res
      refute {:match_filter, "was_live"} in res
      refute {:match_filter, "!was_live"} in res
    end

    test "adds correct filter when livestream_behaviour is :exclude" do
      media_profile = %MediaProfile{@media_profile | livestream_behaviour: :exclude}

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "!was_live"} in res
      refute {:match_filter, "was_live"} in res
      refute {:match_filter, "original_url!*=/shorts/"} in res
      refute {:match_filter, "original_url*=/shorts/"} in res
    end

    test "adds correct filter when shorts and livestreams are both exclude" do
      media_profile = %MediaProfile{
        @media_profile
        | shorts_behaviour: :exclude,
          livestream_behaviour: :exclude
      }

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "!was_live & original_url!*=/shorts/"} in res
      refute {:match_filter, "original_url!*=/shorts/"} in res
      refute {:match_filter, "!was_live"} in res
      refute {:match_filter, "original_url*=/shorts/"} in res
      refute {:match_filter, "was_live"} in res
    end

    test "does not add exclusion filter if one is excluded and the other is only" do
      media_profile = %MediaProfile{
        @media_profile
        | shorts_behaviour: :exclude,
          livestream_behaviour: :only
      }

      assert {:ok, res} = IndexOptionBuilder.build(media_profile)

      assert {:match_filter, "was_live"} in res
      refute {:match_filter, "original_url!*=/shorts/"} in res
      refute {:match_filter, "original_url*=/shorts/"} in res
      refute {:match_filter, "!was_live"} in res
    end
  end
end
