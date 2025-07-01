class RepoState < ApplicationRecord
  belongs_to :step

  # Override attribute readers to ensure diffs are never filtered
  # This prevents corruption where code like "else" becomes "e" due to secret filtering
  def git_diff
    read_attribute(:git_diff)
  end

  def uncommitted_diff
    read_attribute(:uncommitted_diff)
  end

  def target_branch_diff
    read_attribute(:target_branch_diff)
  end

  # Ensure diffs are saved without filtering
  before_save :preserve_diff_integrity

  private

  def preserve_diff_integrity
    # Directly set attributes to bypass any potential filtering
    self[:git_diff] = git_diff if git_diff_changed?
    self[:uncommitted_diff] = uncommitted_diff if uncommitted_diff_changed?
    self[:target_branch_diff] = target_branch_diff if target_branch_diff_changed?
  end
end
