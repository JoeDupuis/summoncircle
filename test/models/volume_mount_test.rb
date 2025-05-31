require "test_helper"

class VolumeMountTest < ActiveSupport::TestCase
  test "generates volume_name for regular volume mount" do
    volume_mount = VolumeMount.create!(
      volume: volumes(:one),
      task: tasks(:two)
    )

    assert_match(/summoncircle_.*_volume_/, volume_mount.volume_name)
  end

  test "generates volume_name for workplace mount" do
    volume_mount = VolumeMount.create!(
      volume: nil,
      task: tasks(:one)
    )

    assert_match(/summoncircle_workplace_volume_/, volume_mount.volume_name)
  end

  test "container_path returns volume path for regular mount" do
    volume_mount = volume_mounts(:one)
    assert_equal volume_mount.volume.path, volume_mount.container_path
  end

  test "container_path returns workplace_path for workplace mount" do
    tasks(:one).agent.update!(workplace_path: "/workspace")
    volume_mount = VolumeMount.create!(
      volume: nil,
      task: tasks(:one)
    )

    assert_equal "/workspace", volume_mount.container_path
  end

  test "bind_string returns volume_name:container_path" do
    volume_mount = volume_mounts(:one)
    expected = "#{volume_mount.volume_name}:#{volume_mount.container_path}"
    assert_equal expected, volume_mount.bind_string
  end
end
