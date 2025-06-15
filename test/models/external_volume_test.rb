require "test_helper"

class ExternalVolumeTest < ActiveSupport::TestCase
  def setup
    @agent = agents(:one)
  end

  test "external volume creates correct volume mount" do
    volume = Volume.create!(
      agent: @agent,
      name: "test_external",
      path: "/test/path",
      external: true,
      external_name: "my_docker_volume"
    )

    task = Task.create!(
      agent: @agent,
      project: projects(:one),
      user: users(:one)
    )

    volume_mount = task.volume_mounts.find_by(volume: volume)
    assert_not_nil volume_mount
    assert_equal "my_docker_volume", volume_mount.volume_name
    assert_equal "my_docker_volume:/test/path", volume_mount.bind_string
  end

  test "regular volume creates unique volume name" do
    volume = Volume.create!(
      agent: @agent,
      name: "test_regular",
      path: "/test/path",
      external: false
    )

    task = Task.create!(
      agent: @agent,
      project: projects(:one),
      user: users(:one)
    )

    volume_mount = task.volume_mounts.find_by(volume: volume)
    assert_not_nil volume_mount
    assert_match(/^summoncircle_test_regular_volume_/, volume_mount.volume_name)
    assert_equal "#{volume_mount.volume_name}:/test/path", volume_mount.bind_string
  end

  test "external volume requires external_name" do
    volume = Volume.new(
      agent: @agent,
      name: "test_external",
      path: "/test/path",
      external: true
    )

    assert_not volume.valid?
    assert_includes volume.errors[:external_name], "can't be blank"
  end
end
