import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../models/todo.dart';
import '../../models/goal.dart';

class TodoListScreen extends StatefulWidget {
  final List<Goal> goals;

  const TodoListScreen({super.key, required this.goals});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Todo> todos = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Daily Todos', style: TextStyle(color: Colors.white)),
      ),
      body: todos.isEmpty
          ? Center(
              child: Text(
                'No todos yet. Add your first task!',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: todos.length,
              itemBuilder: (context, index) {
                return _buildTodoCard(todos[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(),
        backgroundColor: Colors.white.withOpacity(0.2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTodoCard(Todo todo) {
    final goal = widget.goals.firstWhere(
      (g) => g.id == todo.goalId,
      orElse: () => Goal(
        id: '',
        title: 'No Goal',
        description: '',
        type: GoalType.shortTerm,
        createdAt: DateTime.now(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: todo.completed
              ? Colors.green.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
        ),
        color: Colors.white.withOpacity(0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Checkbox(
                  value: todo.completed,
                  onChanged: (value) {
                    setState(() {
                      final index = todos.indexWhere((t) => t.id == todo.id);
                      todos[index] = todo.copyWith(completed: value);
                    });
                  },
                  fillColor: MaterialStateProperty.all(Colors.white.withOpacity(0.3)),
                  checkColor: Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: todo.completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.flag, size: 14, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            goal.title,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (todo.alignmentScore != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: todo.alignmentScore! / 100,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getAlignmentColor(todo.alignmentScore!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${todo.alignmentScore!.toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAlignmentColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  void _showAddTodoDialog() {
    final titleController = TextEditingController();
    String? selectedGoalId = widget.goals.isNotEmpty ? widget.goals.first.id : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Add Todo', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Task',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.goals.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedGoalId,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Related Goal',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  items: widget.goals.map((goal) {
                    return DropdownMenuItem(
                      value: goal.id,
                      child: Text(goal.title),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedGoalId = value);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    todos.add(Todo(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text,
                      goalId: selectedGoalId,
                      createdAt: DateTime.now(),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
