defmodule PinchflatWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PinchflatWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Pinchflat.TestingHelperMethods

  using do
    quote do
      # The default endpoint for testing
      @endpoint PinchflatWeb.Endpoint
      alias Pinchflat.Repo

      use PinchflatWeb, :verified_routes
      use Oban.Testing, repo: Repo

      # Import conveniences for testing with connections

      import Mox
      import Plug.Conn
      import Phoenix.ConnTest
      import PinchflatWeb.ConnCase
      import Pinchflat.TestingHelperMethods

      setup :verify_on_exit!
    end
  end

  setup tags do
    TestingHelperMethods.create_platform_directories()
    Pinchflat.DataCase.setup_sandbox(tags)

    conn = Phoenix.ConnTest.build_conn()
    session_conn = Plug.Test.init_test_session(conn, %{})

    {:ok, conn: conn, session_conn: session_conn}
  end
end
