defmodule Pinchflat.TestingHelperMethods do
  @moduledoc false

  use ExUnit.CaseTemplate

  def now do
    DateTime.utc_now()
  end

  def now_plus(offset, unit) when unit in [:minute, :minutes] do
    DateTime.add(now(), offset, :minute)
  end

  def assert_changed(checker_fun, action_fn) do
    before_res = checker_fun.()
    action_fn.()
    after_res = checker_fun.()

    assert before_res != after_res
  end

  def assert_changed([from: from, to: to], checker_fun, action_fn) do
    before_res = checker_fun.()
    action_fn.()
    after_res = checker_fun.()

    assert before_res == from
    assert after_res == to
  end

  def render_metadata(metadata_name) do
    json_filepath =
      Path.join([
        File.cwd!(),
        "test",
        "support",
        "files",
        "#{metadata_name}.json"
      ])

    File.read!(json_filepath)
  end
end
