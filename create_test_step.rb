content = 'Repository state updated

Uncommitted diff:
diff --git a/test.txt b/test.txt
new file mode 100644
index 0000000..ce01362
--- /dev/null
+++ b/test.txt
@@ -0,0 +1 @@
+hello world'

Step.create!(
  run_id: 1, 
  type: 'Step::System', 
  content: content,
  raw_response: '{"type":"system","content":"' + content.gsub('"', '\"') + '"}'
)
puts "Test step created!"