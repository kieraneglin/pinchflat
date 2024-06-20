defmodule Pinchflat.Platform.AppNotificationParserTest do
  use Pinchflat.DataCase

  import Pinchflat.PlatformFixtures

  alias Pinchflat.Platform.AppNotificationParser

  describe "parse_and_store_notifications/1" do
    test "parses and stores notifications" do
      notification_json = app_notification_json_fixture()

      assert {:ok, notifications} = AppNotificationParser.parse_and_store_notifications(notification_json)
      # assert Enum.count(notifications) == 2
    end
  end
end
