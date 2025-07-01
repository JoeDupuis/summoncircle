require "test_helper"

class TaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "run method should create a new run and queue job" do
    task = tasks(:two)

    assert_difference "Run.count", 1 do
      assert_enqueued_jobs 1, only: RunJob do
        run = task.run("test command")
        assert_equal "test command", run.prompt
        assert run.pending?
      end
    end
  end

  test "workplace_mount returns VolumeMount when agent has workplace_path" do
    task = tasks(:one)

    workplace_mount = task.workplace_mount
    assert_not_nil workplace_mount
    assert_instance_of VolumeMount, workplace_mount
    assert_nil workplace_mount.volume
    assert_equal task, workplace_mount.task
    assert_match(/summoncircle_workplace_volume_/, workplace_mount.volume_name)
  end

  test "enqueues AutoTaskNamingJob when user has auto_task_naming_agent set" do
    user = users(:one)
    agent = agents(:one)
    user.update!(auto_task_naming_agent: agent)

    task = Task.create!(
      project: projects(:one),
      agent: agents(:two),
      user: user,
      runs_attributes: [ { prompt: "Create a login system" } ]
    )

    assert_enqueued_with(job: AutoTaskNamingJob, args: [ task, "Create a login system" ])
  end

  test "does not enqueue AutoTaskNamingJob when user has no auto_task_naming_agent" do
    user = users(:one)
    user.update!(auto_task_naming_agent: nil)

    assert_no_enqueued_jobs only: AutoTaskNamingJob do
      Task.create!(
        project: projects(:one),
        agent: agents(:two),
        user: user,
        runs_attributes: [ { prompt: "Create a login system" } ]
      )
    end
  end

  test "does not enqueue AutoTaskNamingJob when task has custom description" do
    user = users(:one)
    agent = agents(:one)
    user.update!(auto_task_naming_agent: agent)

    assert_no_enqueued_jobs only: AutoTaskNamingJob do
      Task.create!(
        project: projects(:one),
        agent: agents(:two),
        user: user,
        description: "Custom task name",
        runs_attributes: [ { prompt: "Create a login system" } ]
      )
    end
  end
end
