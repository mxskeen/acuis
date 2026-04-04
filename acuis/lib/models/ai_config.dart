/// AI Provider Configuration
///
/// Supports OpenAI-compatible APIs (NVIDIA NIM, OpenAI, Groq, Together, etc.)
class AIConfig {
  // Default configuration - built-in API for all users
  // Users can override with their own keys
  static const String defaultApiUrl = 'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String defaultModel = 'mistralai/mistral-small-4-119b-2603';

  // Built-in API key (injected at build time via --dart-define)
  // Empty string means no built-in key; null-check in getters handles this
  static const String builtInApiKeyRaw = String.fromEnvironment(
    'NVIDIA_API_KEY',
    defaultValue: '',
  );

  // Expose as nullable for cleaner logic - empty string becomes null
  static const String? builtInApiKey = builtInApiKeyRaw == '' ? null : builtInApiKeyRaw;

  final String? customApiKey;
  final String? customApiUrl;
  final String? customModel;
  final bool useCustomProvider;

  const AIConfig({
    this.customApiKey,
    this.customApiUrl,
    this.customModel,
    this.useCustomProvider = false,
  });

  /// Get the effective API key
  String get effectiveApiKey {
    if (useCustomProvider && customApiKey != null && customApiKey!.isNotEmpty) {
      return customApiKey!;
    }
    return builtInApiKey ?? '';
  }

  /// Get the effective API URL
  String get effectiveApiUrl {
    if (useCustomProvider && customApiUrl != null && customApiUrl!.isNotEmpty) {
      return customApiUrl!;
    }
    return defaultApiUrl;
  }

  /// Get the effective model
  String get effectiveModel {
    if (useCustomProvider && customModel != null && customModel!.isNotEmpty) {
      return customModel!;
    }
    return defaultModel;
  }

  /// Check if AI is available (has valid key)
  bool get isAvailable => effectiveApiKey.isNotEmpty;

  /// Check if using built-in provider
  bool get usingBuiltIn => !useCustomProvider && builtInApiKey != null;

  /// Check if using custom provider
  bool get usingCustom => useCustomProvider && customApiKey != null && customApiKey!.isNotEmpty;

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      customApiKey: json['customApiKey'] as String?,
      customApiUrl: json['customApiUrl'] as String?,
      customModel: json['customModel'] as String?,
      useCustomProvider: json['useCustomProvider'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'customApiKey': customApiKey,
    'customApiUrl': customApiUrl,
    'customModel': customModel,
    'useCustomProvider': useCustomProvider,
  };

  AIConfig copyWith({
    String? customApiKey,
    String? customApiUrl,
    String? customModel,
    bool? useCustomProvider,
  }) {
    return AIConfig(
      customApiKey: customApiKey ?? this.customApiKey,
      customApiUrl: customApiUrl ?? this.customApiUrl,
      customModel: customModel ?? this.customModel,
      useCustomProvider: useCustomProvider ?? this.useCustomProvider,
    );
  }
}
