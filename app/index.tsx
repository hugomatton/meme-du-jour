import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { APP_NAME } from '../lib/constants';
import { isSupabaseConfigured } from '../lib/env';
import { useTemplates } from '../lib/queries/templates';
import { strings } from '../lib/strings';
import { theme } from '../lib/theme';

/**
 * Foundation screen: it proves the app boots, the Supabase client is wired and
 * the `templates` table is readable. It is replaced by the group list once
 * authentication lands.
 */
export default function FoundationScreen() {
  const insets = useSafeAreaInsets();
  const templates = useTemplates({ enabled: isSupabaseConfigured });

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + theme.spacing(4) }]}
    >
      <Text style={styles.title}>{APP_NAME}</Text>

      {!isSupabaseConfigured ? (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>{strings.setup.title}</Text>
          <Text style={styles.cardBody}>{strings.setup.missingEnv}</Text>
        </View>
      ) : templates.isPending ? (
        <View style={styles.card}>
          <ActivityIndicator color={theme.colors.accent} />
          <Text style={styles.cardBody}>{strings.setup.checking}</Text>
        </View>
      ) : templates.isError ? (
        <View style={styles.card}>
          <Text style={[styles.cardTitle, styles.error]}>{strings.setup.failed}</Text>
          <Text style={styles.cardBody}>{templates.error.message}</Text>
          <Pressable style={styles.button} onPress={() => void templates.refetch()}>
            <Text style={styles.buttonLabel}>{strings.common.retry}</Text>
          </Pressable>
        </View>
      ) : (
        <View style={styles.card}>
          <Text style={[styles.cardTitle, styles.success]}>{strings.setup.connected}</Text>
          <Text style={styles.cardBody}>{strings.setup.templatesCount(templates.data.length)}</Text>
          {templates.data.length === 0 ? (
            <Text style={styles.cardBody}>{strings.setup.emptyCatalogue}</Text>
          ) : (
            templates.data.map((template) => (
              <Text key={template.id} style={styles.templateRow}>
                {template.image_path} · {template.text_zones.length} zone
                {template.text_zones.length > 1 ? 's' : ''}
              </Text>
            ))
          )}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  content: {
    padding: theme.spacing(2),
    gap: theme.spacing(2),
  },
  title: {
    fontFamily: theme.memeFontFamily,
    fontSize: 34,
    color: theme.colors.text,
    textTransform: 'uppercase',
  },
  card: {
    backgroundColor: theme.colors.surface,
    borderColor: theme.colors.border,
    borderWidth: 1,
    borderRadius: theme.radius,
    padding: theme.spacing(2),
    gap: theme.spacing(1),
  },
  cardTitle: {
    color: theme.colors.text,
    fontSize: 17,
    fontWeight: '600',
  },
  cardBody: {
    color: theme.colors.textMuted,
    fontSize: 15,
    lineHeight: 21,
  },
  templateRow: {
    color: theme.colors.textMuted,
    fontSize: 13,
  },
  error: {
    color: theme.colors.danger,
  },
  success: {
    color: theme.colors.success,
  },
  button: {
    alignSelf: 'flex-start',
    marginTop: theme.spacing(1),
    paddingVertical: theme.spacing(1),
    paddingHorizontal: theme.spacing(2),
    borderRadius: theme.radius,
    backgroundColor: theme.colors.accent,
  },
  buttonLabel: {
    color: theme.colors.background,
    fontWeight: '700',
  },
});
