Mox.defmock(CommandRunnerMock, for: Pinchflat.Downloader.Backends.BackendCommandRunner)
Application.put_env(:pinchflat, :yt_dlp_runner, CommandRunnerMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pinchflat.Repo, :manual)
