Mox.defmock(YtDlpRunnerMock, for: Pinchflat.YtDlp.YtDlpCommandRunner)
Application.put_env(:pinchflat, :yt_dlp_runner, YtDlpRunnerMock)

Mox.defmock(AppriseRunnerMock, for: Pinchflat.Lifecycle.Notifications.AppriseCommandRunner)
Application.put_env(:pinchflat, :apprise_runner, AppriseRunnerMock)

Mox.defmock(HTTPClientMock, for: Pinchflat.HTTP.HTTPBehaviour)
Application.put_env(:pinchflat, :http_client, HTTPClientMock)

Mox.defmock(UserScriptRunnerMock, for: Pinchflat.Lifecycle.UserScripts.UserScriptCommandRunner)
Application.put_env(:pinchflat, :user_script_runner, UserScriptRunnerMock)

if System.get_env("EX_CHECK"), do: Code.put_compiler_option(:warnings_as_errors, true)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pinchflat.Repo, :manual)
Faker.start()

ExUnit.after_suite(fn _ ->
  File.rm_rf!(Application.get_env(:pinchflat, :media_directory))
  File.rm_rf!(Application.get_env(:pinchflat, :metadata_directory))
  File.rm_rf!(Application.get_env(:pinchflat, :extras_directory))
  File.rm_rf!(Application.get_env(:pinchflat, :tmpfile_directory))

  File.mkdir_p!(Application.get_env(:pinchflat, :media_directory))
  File.mkdir_p!(Application.get_env(:pinchflat, :metadata_directory))
  File.mkdir_p!(Application.get_env(:pinchflat, :extras_directory))
  File.mkdir_p!(Application.get_env(:pinchflat, :tmpfile_directory))
end)
