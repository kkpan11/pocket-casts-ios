# frozen_string_literal: true

github.dismiss_out_of_range_messages

# `files: []` forces rubocop to scan all files, not just the ones modified in the PR
rubocop.lint(files: [], force_exclusion: true, inline_comment: true, fail_on_inline_comment: true, include_cop_names: true)

manifest_pr_checker.check_all_manifest_lock_updated

# skip remaining checks if we're in a release-process PR
if github.pr_labels.include?('Releases')
  message('This PR has the `Releases` label: some checks will be skipped.')
  return
end

view_changes_checker.check

pr_size_checker.check_diff_size(max_size: 500)

# skip remaining checks if we have a Draft PR
return if github.pr_draft?

labels_checker.check(
  do_not_merge_labels: ['Do Not Merge'],
  required_labels: [//],
  required_labels_error: 'PR requires at least one label.'
)

milestone_checker.check_milestone_due_date(days_before_due: 2)

warn('PR is classed as Work in Progress') if github_utils.wip_feature?
