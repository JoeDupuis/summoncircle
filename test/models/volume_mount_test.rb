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
end
