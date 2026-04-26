/// Canonical topic keys — must match the IDs in
/// `lib/features/onboarding/screens/topic_picker_screen.dart`.
class TopicKeys {
  TopicKeys._();

  static const aiBasics = 'ai_basics';
  static const machineLearning = 'machine_learning';
  static const chatgptLlms = 'chatgpt_llms';
  static const computerVision = 'computer_vision';
  static const generativeAi = 'generative_ai';
  static const aiEthics = 'ai_ethics';
  static const dataScience = 'data_science';
  static const aiBusiness = 'ai_business';
  static const promptEngineering = 'prompt_engineering';
  static const futureAi = 'future_ai';

  static const Set<String> all = {
    aiBasics,
    machineLearning,
    chatgptLlms,
    computerVision,
    generativeAi,
    aiEthics,
    dataScience,
    aiBusiness,
    promptEngineering,
    futureAi,
  };

  /// Maps human-readable card topic tags to canonical keys. Anything not in
  /// this map falls back to a slugified form, which still works for ranker
  /// tie-breaking but won't match user-selected topics.
  static const Map<String, String> _tagAliases = {
    'AI Basics': aiBasics,
    'AI Types': aiBasics,
    'AI History': aiBasics,
    'AI Learning': machineLearning,
    'Machine Learning': machineLearning,
    'Deep Learning': machineLearning,
    'Neural Networks': machineLearning,
    'ChatGPT & LLMs': chatgptLlms,
    'LLMs': chatgptLlms,
    'Chatbots': chatgptLlms,
    'Computer Vision': computerVision,
    'Vision': computerVision,
    'Generative AI': generativeAi,
    'Image Generation': generativeAi,
    'AI Ethics': aiEthics,
    'Ethics': aiEthics,
    'Bias': aiEthics,
    'Data Science': dataScience,
    'Data': dataScience,
    'Statistics': dataScience,
    'AI in Business': aiBusiness,
    'Business': aiBusiness,
    'Careers': aiBusiness,
    'Prompt Engineering': promptEngineering,
    'Prompts': promptEngineering,
    'Future of AI': futureAi,
    'AGI': futureAi,
  };

  static String fromTag(String tag) {
    final mapped = _tagAliases[tag];
    if (mapped != null) return mapped;
    return tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
