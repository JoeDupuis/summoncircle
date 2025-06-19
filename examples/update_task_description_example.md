# UpdateTaskDescriptionTool Usage Example

This MCP tool allows AI models to update the description of a task programmatically.

## Tool Details

- **Name**: `UpdateTaskDescriptionTool`
- **Description**: Update the description of a task
- **Arguments**:
  - `task_id` (required, integer): ID of the task to update
  - `description` (required, string): New description for the task

## Example Usage

### Successful Update
```json
{
  "tool": "UpdateTaskDescriptionTool",
  "arguments": {
    "task_id": 123,
    "description": "Implement authentication system with OAuth 2.0 support"
  }
}
```

**Response:**
```json
{
  "success": true,
  "task_id": 123,
  "description": "Implement authentication system with OAuth 2.0 support",
  "message": "Task description updated successfully"
}
```

### Task Not Found
```json
{
  "tool": "UpdateTaskDescriptionTool",
  "arguments": {
    "task_id": 999999,
    "description": "New description"
  }
}
```

**Response:**
```json
{
  "success": false,
  "error": "Task not found with ID: 999999"
}
```

### Validation Error (Empty Description)
```json
{
  "tool": "UpdateTaskDescriptionTool",
  "arguments": {
    "task_id": 123,
    "description": ""
  }
}
```

**Response:**
```json
{
  "success": false,
  "errors": ["Description can't be blank"],
  "message": "Failed to update task description"
}
```

## Integration with AI Agents

AI agents can use this tool to:
1. Update task descriptions based on progress or new requirements
2. Clarify task objectives after analyzing code
3. Add implementation details discovered during task execution
4. Refine task descriptions for better clarity

The tool is automatically registered with the MCP system and will be available to any AI agent that has access to the MCP tools.