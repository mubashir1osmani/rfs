import React, { useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { initialCalendar, initialMessages, initialTasks } from './src/data';
import { askAssistant, hasRemoteAssistant } from './src/services/assistant';
import { executeConnectedAction, openCalendarAction, openEmailAction } from './src/services/integrations';
import { categoryColors, colors } from './src/theme';
import {
  AssistantAction,
  CalendarBlock,
  ChatMessage,
  ConnectionState,
  Tab,
  Task,
} from './src/types';

const actionId = () => `item-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;

const formatTime = (iso: string) => new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

const formatDay = () => new Date().toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });

const greetingForNow = () => {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
};

const actionTone = (kind: AssistantAction['kind']) => {
  if (kind === 'email') return colors.peach;
  if (kind === 'meeting') return colors.violet;
  if (kind === 'calendar') return colors.blue;
  return colors.mint;
};

const actionIcon = (kind: AssistantAction['kind']) => {
  if (kind === 'email') return '✉';
  if (kind === 'meeting') return '◎';
  if (kind === 'calendar') return '▦';
  return '✓';
};

const actionLabel = (kind: AssistantAction['kind']) => {
  if (kind === 'email') return 'EMAIL DRAFT';
  if (kind === 'meeting') return 'MEETING INVITE';
  if (kind === 'calendar') return 'TIME BLOCK';
  return 'NEW TASK';
};

export default function App() {
  const [tab, setTab] = useState<Tab>('home');
  const [tasks, setTasks] = useState<Task[]>(initialTasks);
  const [calendar, setCalendar] = useState<CalendarBlock[]>(initialCalendar);
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [input, setInput] = useState('');
  const [thinking, setThinking] = useState(false);
  const [actionStates, setActionStates] = useState<Record<string, 'done' | 'dismissed'>>({});
  const [connections, setConnections] = useState<ConnectionState>({ calendar: false, gmail: false });
  const [autonomy, setAutonomy] = useState(true);
  const [showCapture, setShowCapture] = useState(false);
  const [captureText, setCaptureText] = useState('');
  const chatRef = useRef<ScrollView>(null);

  const completedCount = tasks.filter((task) => task.completed).length;
  const nextEvent = [...calendar]
    .filter((event) => new Date(event.start).getTime() >= Date.now() - 60 * 60_000)
    .sort((left, right) => new Date(left.start).getTime() - new Date(right.start).getTime())[0];

  const executeAction = async (action: AssistantAction, openExternal = true) => {
    try {
      if (action.kind === 'task') {
        setTasks((current) => current.some((task) => task.id === action.id) ? current : [
          ...current,
          { id: action.id, title: action.title, dueLabel: action.dueLabel, category: action.category, completed: false },
        ]);
      }

      if (action.kind === 'calendar' || action.kind === 'meeting') {
        setCalendar((current) => current.some((event) => event.id === action.id) ? current : [
          ...current,
          {
            id: action.id,
            title: action.title,
            start: action.start,
            durationMinutes: action.durationMinutes,
            color: actionTone(action.kind),
            source: 'nori',
            attendees: action.attendees,
          },
        ]);
        if (openExternal && !await executeConnectedAction(action)) await openCalendarAction(action);
      }

      if (action.kind === 'email' && openExternal && !await executeConnectedAction(action)) await openEmailAction(action);
      setActionStates((current) => ({ ...current, [action.id]: 'done' }));
    } catch {
      Alert.alert('Could not open the connected app', 'The plan is saved in Nori. Check that Calendar or Mail is available on this device.');
    }
  };

  const sendMessage = async (preset?: string) => {
    const text = (preset ?? input).trim();
    if (!text || thinking) return;
    const userMessage: ChatMessage = { id: actionId(), role: 'user', text };
    setMessages((current) => [...current, userMessage]);
    setInput('');
    setTab('assistant');
    setThinking(true);

    const reply = await askAssistant(text, {
      tasks,
      calendar,
      currentDate: new Date().toISOString(),
    });
    const assistantMessage: ChatMessage = { id: actionId(), role: 'assistant', text: reply.message, actions: reply.actions };
    setMessages((current) => [...current, assistantMessage]);
    setThinking(false);

    if (autonomy) {
      for (const action of reply.actions) {
        if (action.kind === 'task') await executeAction(action, false);
      }
    }
    requestAnimationFrame(() => chatRef.current?.scrollToEnd({ animated: true }));
  };

  const addQuickTask = () => {
    const title = captureText.trim();
    if (!title) return;
    setTasks((current) => [...current, {
      id: actionId(),
      title,
      dueLabel: 'Today',
      category: 'Personal',
      completed: false,
    }]);
    setCaptureText('');
    setShowCapture(false);
  };

  const dismissAction = (action: AssistantAction) => setActionStates((current) => ({ ...current, [action.id]: 'dismissed' }));

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="light-content" />
      <View style={styles.app}>
        {tab === 'home' && (
          <HomeScreen
            tasks={tasks}
            calendar={calendar}
            completedCount={completedCount}
            nextEvent={nextEvent}
            onPrompt={sendMessage}
            onOpenAssistant={() => setTab('assistant')}
            onDemo={() => sendMessage('Show me the Nori demo')}
            onCapture={() => setShowCapture(true)}
            onToggleTask={(id) => setTasks((current) => current.map((task) => task.id === id ? { ...task, completed: !task.completed } : task))}
          />
        )}
        {tab === 'assistant' && (
          <AssistantScreen
            messages={messages}
            input={input}
            thinking={thinking}
            actionStates={actionStates}
            chatRef={chatRef}
            onInput={setInput}
            onSend={sendMessage}
            onExecute={executeAction}
            onDismiss={dismissAction}
          />
        )}
        {tab === 'day' && (
          <DayScreen
            tasks={tasks}
            calendar={calendar}
            onToggleTask={(id) => setTasks((current) => current.map((task) => task.id === id ? { ...task, completed: !task.completed } : task))}
            onPlan={() => sendMessage('Plan and time block my day around my open priorities')}
          />
        )}
        {tab === 'settings' && (
          <SettingsScreen
            autonomy={autonomy}
            connections={connections}
            onAutonomy={setAutonomy}
            onConnection={(key) => setConnections((current) => ({ ...current, [key]: !current[key] }))}
          />
        )}
        <BottomNavigation tab={tab} onChange={setTab} />
      </View>

      <Modal visible={showCapture} transparent animationType="slide" onRequestClose={() => setShowCapture(false)}>
        <KeyboardAvoidingView style={styles.modalBackdrop} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={styles.captureSheet}>
            <View style={styles.sheetHandle} />
            <Text style={styles.sheetEyebrow}>QUICK CAPTURE</Text>
            <Text style={styles.sheetTitle}>What needs your attention?</Text>
            <TextInput
              autoFocus
              value={captureText}
              onChangeText={setCaptureText}
              onSubmitEditing={addQuickTask}
              placeholder="Finish the presentation"
              placeholderTextColor={colors.textFaint}
              style={styles.captureInput}
              returnKeyType="done"
            />
            <Pressable style={styles.primaryButton} onPress={addQuickTask}>
              <Text style={styles.primaryButtonText}>Add to my day</Text>
              <Text style={styles.primaryButtonIcon}>→</Text>
            </Pressable>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaView>
  );
}

type HomeProps = {
  tasks: Task[];
  calendar: CalendarBlock[];
  completedCount: number;
  nextEvent?: CalendarBlock;
  onPrompt: (prompt: string) => void;
  onOpenAssistant: () => void;
  onDemo: () => void;
  onCapture: () => void;
  onToggleTask: (id: string) => void;
};

function HomeScreen({ tasks, calendar, completedCount, nextEvent, onPrompt, onOpenAssistant, onDemo, onCapture, onToggleTask }: HomeProps) {
  const openTasks = tasks.filter((task) => !task.completed);
  const focusMinutes = calendar.reduce((total, event) => total + event.durationMinutes, 0);
  return (
    <ScrollView contentContainerStyle={styles.page} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
      <View style={styles.homeHeader}>
        <View>
          <Text style={styles.eyebrow}>{formatDay().toUpperCase()}</Text>
          <Text style={styles.greeting}>{greetingForNow()},</Text>
          <Text style={styles.greetingName}>Mubashir.</Text>
        </View>
        <View style={styles.avatar}><Text style={styles.avatarText}>M</Text><View style={styles.liveDot} /></View>
      </View>

      <View style={styles.commandCard}>
        <View style={styles.commandGlow} />
        <View style={styles.commandTopline}><Text style={styles.commandMark}>✦</Text><View style={styles.autonomyPill}><View style={styles.autonomyDot} /><Text style={styles.autonomyText}>AUTONOMY ON</Text></View></View>
        <Text style={styles.commandTitle}>What can I take off your mind?</Text>
        <Text style={styles.commandSubtitle}>Talk naturally. I’ll plan it, schedule it, or draft it.</Text>
        <Pressable accessibilityRole="button" accessibilityLabel="Open Nori assistant" style={({ pressed }) => [styles.commandInput, pressed && styles.pressed]} onPress={onOpenAssistant}>
          <Text style={styles.commandPlaceholder}>Ask Nori anything…</Text>
          <View style={styles.voiceOrb}><Text style={styles.voiceOrbText}>◉</Text></View>
        </Pressable>
        <View style={styles.promptRow}>
          <PromptChip label="Plan my day" onPress={() => onPrompt('Plan and time block my day around my priorities')} />
          <PromptChip label="Book a meeting" onPress={() => onPrompt('Book a 30 minute meeting tomorrow at 3 PM')} />
        </View>
        <Pressable accessibilityRole="button" accessibilityLabel="Run the Nori guided demo" style={({ pressed }) => [styles.demoButton, pressed && styles.pressed]} onPress={onDemo}>
          <View><Text style={styles.demoEyebrow}>NEW TO NORI?</Text><Text style={styles.demoButtonText}>Watch a 20-second action demo</Text></View>
          <Text style={styles.demoArrow}>→</Text>
        </Pressable>
      </View>

      <View style={styles.metricsRow}>
        <MetricCard value={`${openTasks.length}`} label="open priorities" color={colors.mint} />
        <MetricCard value={`${Math.round(focusMinutes / 60)}h`} label="time protected" color={colors.violet} />
        <MetricCard value={`${completedCount}`} label="done today" color={colors.yellow} />
      </View>

      <SectionHeading title="NEXT UP" action={nextEvent ? formatTime(nextEvent.start) : 'CLEAR'} />
      <View style={styles.nextCard}>
        <View style={styles.nextTime}><Text style={styles.nextTimeText}>{nextEvent ? formatTime(nextEvent.start) : '—'}</Text></View>
        <View style={styles.nextLine} />
        <View style={styles.nextCopy}>
          <Text style={styles.nextTitle}>{nextEvent?.title || 'Your calendar is open'}</Text>
          <Text style={styles.nextMeta}>{nextEvent ? `${nextEvent.durationMinutes} minutes · ${nextEvent.source === 'nori' ? 'Planned by Nori' : 'Calendar'}` : 'Ask Nori to protect some focus time'}</Text>
        </View>
        <Text style={styles.chevron}>›</Text>
      </View>

      <SectionHeading title="PRIORITIES" action="TODAY" />
      <View style={styles.taskGroup}>
        {tasks.slice(0, 4).map((task) => <TaskRow key={task.id} task={task} onToggle={onToggleTask} />)}
      </View>
      <Pressable style={styles.captureButton} onPress={onCapture}>
        <Text style={styles.capturePlus}>＋</Text><Text style={styles.captureButtonText}>Capture a task</Text>
      </Pressable>
      <Pressable accessibilityRole="button" accessibilityLabel="Ask Nori to rebalance the afternoon" style={({ pressed }) => [styles.nudgeCard, pressed && styles.pressed]} onPress={() => onPrompt('Rebalance my afternoon and move one low-priority task if needed')}>
        <Text style={styles.nudgeIcon}>☼</Text>
        <View style={styles.nudgeCopy}><Text style={styles.nudgeLabel}>NORI NOTICED</Text><Text style={styles.nudgeText}>You have a full afternoon. Want me to move one low-priority task?</Text></View>
        <Text style={styles.chevron}>›</Text>
      </Pressable>
    </ScrollView>
  );
}

type AssistantProps = {
  messages: ChatMessage[];
  input: string;
  thinking: boolean;
  actionStates: Record<string, 'done' | 'dismissed'>;
  chatRef: React.RefObject<ScrollView | null>;
  onInput: (value: string) => void;
  onSend: (preset?: string) => void;
  onExecute: (action: AssistantAction) => void;
  onDismiss: (action: AssistantAction) => void;
};

function AssistantScreen({ messages, input, thinking, actionStates, chatRef, onInput, onSend, onExecute, onDismiss }: AssistantProps) {
  return (
    <KeyboardAvoidingView style={styles.assistantPage} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={8}>
      <View style={styles.assistantHeader}>
        <View><Text style={styles.eyebrow}>YOUR AUTONOMOUS ASSISTANT</Text><Text style={styles.screenTitle}>Nori</Text></View>
        <View style={styles.onlineBadge}><View style={styles.onlineBadgeDot} /><Text style={styles.onlineBadgeText}>ONLINE</Text></View>
      </View>
      <ScrollView ref={chatRef} style={styles.chat} contentContainerStyle={styles.chatContent} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled" onContentSizeChange={() => chatRef.current?.scrollToEnd({ animated: true })}>
        {messages.map((message) => (
          <View key={message.id} style={[styles.messageStack, message.role === 'user' && styles.userStack]}>
            {message.role === 'assistant' && <View style={styles.messageIdentity}><View style={styles.smallMark}><Text style={styles.smallMarkText}>✦</Text></View><Text style={styles.messageIdentityText}>NORI</Text></View>}
            <View style={[styles.messageBubble, message.role === 'user' ? styles.userBubble : styles.assistantBubble]}>
              <Text style={[styles.messageText, message.role === 'user' && styles.userMessageText]}>{message.text}</Text>
            </View>
            {message.actions?.map((action) => (
              <ActionCard key={action.id} action={action} state={actionStates[action.id]} onExecute={() => onExecute(action)} onDismiss={() => onDismiss(action)} />
            ))}
          </View>
        ))}
        {thinking && <View style={styles.thinkingRow} accessibilityLiveRegion="polite"><ActivityIndicator color={colors.mint} /><Text style={styles.thinkingText}>Nori is making a plan…</Text></View>}
      </ScrollView>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.suggestionRow}>
        {['Plan my day', 'Block focus time', 'Draft an email', 'Book a meeting'].map((label) => (
          <Pressable key={label} accessibilityRole="button" style={({ pressed }) => [styles.suggestionChip, pressed && styles.pressed]} onPress={() => onSend(label)}><Text style={styles.suggestionText}>{label}</Text></Pressable>
        ))}
      </ScrollView>
      <View style={styles.composer}>
        <Pressable accessibilityRole="button" accessibilityLabel="How to dictate a request" style={({ pressed }) => [styles.dictationButton, pressed && styles.pressed]} onPress={() => Alert.alert('Talk to Nori', 'Tap the microphone on the iOS keyboard and speak naturally. Nori will turn your words into actions.')}><Text style={styles.dictationIcon}>◉</Text></Pressable>
        <TextInput
          accessibilityLabel="Message Nori"
          value={input}
          onChangeText={onInput}
          onSubmitEditing={() => onSend()}
          placeholder="Tell Nori what you need…"
          placeholderTextColor={colors.textFaint}
          style={styles.composerInput}
          returnKeyType="send"
          multiline
          maxLength={1200}
          submitBehavior="submit"
        />
        <Pressable accessibilityRole="button" accessibilityLabel="Send message" accessibilityState={{ disabled: !input.trim(), busy: thinking }} style={({ pressed }) => [styles.sendButton, !input.trim() && styles.sendButtonDisabled, pressed && styles.pressed]} onPress={() => onSend()} disabled={!input.trim()}><Text style={styles.sendButtonText}>↑</Text></Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

function ActionCard({ action, state, onExecute, onDismiss }: { action: AssistantAction; state?: 'done' | 'dismissed'; onExecute: () => void; onDismiss: () => void }) {
  const tone = actionTone(action.kind);
  const title = action.kind === 'email' ? action.subject : action.title;
  const detail = action.kind === 'email'
    ? `${action.to || 'Choose recipient'} · Ready to review`
    : action.kind === 'task'
      ? `${action.dueLabel} · ${action.category}`
      : `${formatTime(action.start)} · ${action.durationMinutes} min${action.attendees.length ? ` · ${action.attendees.join(', ')}` : ''}`;
  const buttonLabel = action.kind === 'email' ? 'Open in Mail' : action.kind === 'meeting' ? 'Create invite' : action.kind === 'calendar' ? 'Add to Calendar' : 'Add task';

  if (state === 'dismissed') return <View style={styles.dismissedCard}><Text style={styles.dismissedText}>Action dismissed</Text></View>;
  return (
    <View style={[styles.actionCard, { borderColor: `${tone}55` }]}>
      <View style={styles.actionHeader}>
        <View style={[styles.actionIcon, { backgroundColor: `${tone}18` }]}><Text style={[styles.actionIconText, { color: tone }]}>{actionIcon(action.kind)}</Text></View>
        <Text style={[styles.actionLabel, { color: tone }]}>{actionLabel(action.kind)}</Text>
        {!state && <Pressable accessibilityRole="button" accessibilityLabel={`Dismiss ${actionLabel(action.kind).toLowerCase()}`} hitSlop={8} onPress={onDismiss} style={styles.dismissButton}><Text style={styles.dismissButtonText}>×</Text></Pressable>}
      </View>
      <Text style={styles.actionTitle}>{title}</Text>
      <Text style={styles.actionDetail}>{detail}</Text>
      {action.kind === 'email' && <View style={styles.emailPreview}><Text style={styles.emailPreviewText}>{action.body}</Text></View>}
      <Pressable accessibilityRole="button" accessibilityState={{ disabled: state === 'done' }} style={({ pressed }) => [styles.actionButton, state === 'done' && styles.actionButtonDone, pressed && styles.pressed]} onPress={onExecute} disabled={state === 'done'}>
        <Text style={styles.actionButtonText}>{state === 'done' ? 'Added to your day' : buttonLabel}</Text>
        <Text style={styles.actionButtonArrow}>{state === 'done' ? '✓' : '→'}</Text>
      </Pressable>
    </View>
  );
}

function DayScreen({ tasks, calendar, onToggleTask, onPlan }: { tasks: Task[]; calendar: CalendarBlock[]; onToggleTask: (id: string) => void; onPlan: () => void }) {
  const orderedEvents = useMemo(() => [...calendar].sort((left, right) => new Date(left.start).getTime() - new Date(right.start).getTime()), [calendar]);
  return (
    <ScrollView contentContainerStyle={styles.page} showsVerticalScrollIndicator={false}>
      <View style={styles.dayHeader}><View><Text style={styles.eyebrow}>{formatDay().toUpperCase()}</Text><Text style={styles.screenTitle}>My day</Text></View><Pressable style={styles.planButton} onPress={onPlan}><Text style={styles.planButtonText}>✦ Plan for me</Text></Pressable></View>
      <View style={styles.daySummary}>
        <View><Text style={styles.summaryValue}>{calendar.length}</Text><Text style={styles.summaryLabel}>calendar blocks</Text></View>
        <View style={styles.summaryDivider} />
        <View><Text style={styles.summaryValue}>{tasks.filter((task) => !task.completed).length}</Text><Text style={styles.summaryLabel}>priorities left</Text></View>
      </View>
      <SectionHeading title="SCHEDULE" action="TODAY" />
      <View style={styles.timeline}>
        {orderedEvents.map((event) => (
          <View style={styles.timelineRow} key={event.id}>
            <Text style={styles.timelineTime}>{formatTime(event.start)}</Text>
            <View style={[styles.timelineBar, { backgroundColor: event.color }]} />
            <View style={styles.timelineEvent}><Text style={styles.timelineTitle}>{event.title}</Text><Text style={styles.timelineMeta}>{event.durationMinutes} min{event.source === 'nori' ? ' · Planned by Nori' : ''}</Text></View>
          </View>
        ))}
      </View>
      <SectionHeading title="TASKS" action={`${tasks.filter((task) => !task.completed).length} LEFT`} />
      <View style={styles.taskGroup}>{tasks.length ? tasks.map((task) => <TaskRow key={task.id} task={task} onToggle={onToggleTask} />) : <EmptyState title="Nothing left today" detail="Enjoy the space, or ask Nori to plan tomorrow." />}</View>
    </ScrollView>
  );
}

function SettingsScreen({ autonomy, connections, onAutonomy, onConnection }: { autonomy: boolean; connections: ConnectionState; onAutonomy: (value: boolean) => void; onConnection: (key: keyof ConnectionState) => void }) {
  return (
    <ScrollView contentContainerStyle={styles.page} showsVerticalScrollIndicator={false}>
      <Text style={styles.eyebrow}>MAKE NORI YOURS</Text><Text style={styles.screenTitle}>Settings</Text>
      <View style={styles.profileCard}><View style={styles.largeAvatar}><Text style={styles.largeAvatarText}>M</Text></View><View style={styles.profileCopy}><Text style={styles.profileName}>Mubashir</Text><Text style={styles.profileSub}>Student · Builder · Getting things done</Text></View><Text style={styles.chevron}>›</Text></View>
      <SectionHeading title="AUTONOMY" action={autonomy ? 'ON' : 'OFF'} />
      <View style={styles.settingsGroup}>
        <View style={styles.settingRow}><View style={[styles.settingIcon, { backgroundColor: `${colors.mint}18` }]}><Text style={{ color: colors.mint }}>✦</Text></View><View style={styles.settingCopy}><Text style={styles.settingTitle}>Act on safe requests</Text><Text style={styles.settingDescription}>Nori adds tasks automatically. Calendar, meetings, and email still require your approval.</Text></View><Switch value={autonomy} onValueChange={onAutonomy} trackColor={{ false: colors.border, true: '#356F4B' }} thumbColor={autonomy ? colors.mint : colors.textMuted} /></View>
      </View>
      <SectionHeading title="CONNECTIONS" action="WORKSPACE" />
      <View style={styles.settingsGroup}>
        <ConnectionRow icon="G" tone={colors.blue} title="Google Calendar" detail="Time blocks and meeting invites" connected={connections.calendar} onPress={() => onConnection('calendar')} />
        <View style={styles.settingDivider} />
        <ConnectionRow icon="M" tone={colors.peach} title="Gmail" detail="Draft and review messages" connected={connections.gmail} onPress={() => onConnection('gmail')} />
      </View>
      <SectionHeading title="AI ENGINE" action={hasRemoteAssistant ? 'CONNECTED' : 'LOCAL'} />
      <View style={styles.engineCard}><View style={styles.engineTop}><Text style={styles.engineMark}>✦</Text><View><Text style={styles.engineTitle}>{hasRemoteAssistant ? 'Nori Intelligence connected' : 'Smart local planner'}</Text><Text style={styles.engineSub}>{hasRemoteAssistant ? 'Using your private assistant endpoint' : 'Works offline with natural-language actions'}</Text></View></View><Text style={styles.engineBody}>Set EXPO_PUBLIC_NORI_API_URL to connect your own secure AI backend. Never place a private AI key directly in a mobile app.</Text></View>
      <View style={styles.safetyCard}><Text style={styles.safetyLabel}>APPROVAL BOUNDARY</Text><Text style={styles.safetyText}>Nori can plan autonomously. Anything that contacts another person or changes an external calendar stays visible and reviewable before it happens.</Text></View>
    </ScrollView>
  );
}

function ConnectionRow({ icon, tone, title, detail, connected, onPress }: { icon: string; tone: string; title: string; detail: string; connected: boolean; onPress: () => void }) {
  return <View style={styles.connectionRow}><View style={[styles.connectionLogo, { backgroundColor: `${tone}18` }]}><Text style={[styles.connectionLogoText, { color: tone }]}>{icon}</Text></View><View style={styles.settingCopy}><Text style={styles.settingTitle}>{title}</Text><Text style={styles.settingDescription}>{detail}</Text></View><Pressable accessibilityRole="button" accessibilityLabel={`${connected ? 'Disconnect' : 'Connect'} ${title}`} accessibilityState={{ selected: connected }} style={({ pressed }) => [styles.connectButton, connected && styles.connectedButton, pressed && styles.pressed]} onPress={onPress}><Text style={[styles.connectButtonText, connected && styles.connectedButtonText]}>{connected ? 'Connected' : 'Connect'}</Text></Pressable></View>;
}

function TaskRow({ task, onToggle }: { task: Task; onToggle: (id: string) => void }) {
  return <Pressable accessibilityRole="checkbox" accessibilityLabel={task.title} accessibilityHint={`${task.dueLabel}, ${task.category}`} accessibilityState={{ checked: task.completed }} style={({ pressed }) => [styles.taskRow, pressed && styles.taskRowPressed]} onPress={() => onToggle(task.id)}><View style={[styles.taskCheck, task.completed && styles.taskCheckDone, { borderColor: task.completed ? colors.mint : categoryColors[task.category] }]}>{task.completed && <Text style={styles.taskCheckMark}>✓</Text>}</View><View style={styles.taskCopy}><Text style={[styles.taskTitle, task.completed && styles.taskTitleDone]}>{task.title}</Text><Text style={styles.taskMeta}>{task.dueLabel} · {task.category}</Text></View><View style={[styles.taskCategory, { backgroundColor: categoryColors[task.category] }]} /></Pressable>;
}

function PromptChip({ label, onPress }: { label: string; onPress: () => void }) {
  return <Pressable accessibilityRole="button" style={({ pressed }) => [styles.promptChip, pressed && styles.pressed]} onPress={onPress}><Text style={styles.promptChipText}>{label}</Text><Text style={styles.promptChipArrow}>↗</Text></Pressable>;
}

function EmptyState({ title, detail }: { title: string; detail: string }) {
  return <View style={styles.emptyState}><Text style={styles.emptyStateIcon}>✓</Text><Text style={styles.emptyStateTitle}>{title}</Text><Text style={styles.emptyStateDetail}>{detail}</Text></View>;
}

function MetricCard({ value, label, color }: { value: string; label: string; color: string }) {
  return <View style={styles.metricCard}><Text style={[styles.metricValue, { color }]}>{value}</Text><Text style={styles.metricLabel}>{label}</Text></View>;
}

function SectionHeading({ title, action }: { title: string; action: string }) {
  return <View style={styles.sectionHeading}><Text style={styles.sectionTitle}>{title}</Text><Text style={styles.sectionAction}>{action}</Text></View>;
}

function BottomNavigation({ tab, onChange }: { tab: Tab; onChange: (tab: Tab) => void }) {
  const items: { tab: Tab; label: string; icon: string }[] = [
    { tab: 'home', label: 'Home', icon: '⌂' },
    { tab: 'assistant', label: 'Nori', icon: '✦' },
    { tab: 'day', label: 'My day', icon: '▤' },
    { tab: 'settings', label: 'You', icon: '○' },
  ];
  return <View style={styles.bottomNav}>{items.map((item) => <Pressable key={item.tab} accessibilityRole="tab" accessibilityLabel={item.label} accessibilityState={{ selected: tab === item.tab }} style={({ pressed }) => [styles.navItem, pressed && styles.pressed]} onPress={() => onChange(item.tab)}><View style={[styles.navIcon, tab === item.tab && styles.navIconActive]}><Text style={[styles.navIconText, tab === item.tab && styles.navIconTextActive]}>{item.icon}</Text></View><Text style={[styles.navLabel, tab === item.tab && styles.navLabelActive]}>{item.label}</Text></Pressable>)}</View>;
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: colors.background },
  app: { flex: 1, backgroundColor: colors.background },
  page: { width: '100%', maxWidth: 620, alignSelf: 'center', paddingHorizontal: 20, paddingTop: 18, paddingBottom: 116 },
  pressed: { opacity: 0.72 },
  eyebrow: { color: colors.textMuted, fontSize: 10, fontWeight: '800', letterSpacing: 1.55 },
  homeHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 24 },
  greeting: { color: colors.text, fontSize: 28, fontWeight: '500', letterSpacing: -0.9, marginTop: 8 },
  greetingName: { color: colors.mint, fontSize: 28, fontWeight: '700', letterSpacing: -0.9 },
  avatar: { width: 44, height: 44, borderRadius: 16, backgroundColor: colors.mint, justifyContent: 'center', alignItems: 'center' },
  avatarText: { color: colors.black, fontSize: 17, fontWeight: '900' },
  liveDot: { position: 'absolute', width: 11, height: 11, borderRadius: 6, right: -2, bottom: 2, backgroundColor: colors.mintStrong, borderWidth: 2, borderColor: colors.background },
  commandCard: { overflow: 'hidden', backgroundColor: colors.surfaceRaised, borderRadius: 24, borderWidth: 1, borderColor: '#355547', padding: 19, marginBottom: 14 },
  commandGlow: { position: 'absolute', width: 180, height: 180, borderRadius: 90, backgroundColor: '#2E704A44', top: -105, right: -55 },
  commandTopline: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 15 },
  commandMark: { color: colors.mint, fontSize: 22 },
  autonomyPill: { minHeight: 27, borderRadius: 14, paddingHorizontal: 10, flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: '#1F392B', borderWidth: 1, borderColor: '#315D43' },
  autonomyDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.mintStrong },
  autonomyText: { color: colors.mint, fontSize: 8, fontWeight: '800', letterSpacing: 0.9 },
  commandTitle: { color: colors.text, fontSize: 21, lineHeight: 27, fontWeight: '700', letterSpacing: -0.45, maxWidth: 285 },
  commandSubtitle: { color: colors.textMuted, fontSize: 12, lineHeight: 18, marginTop: 7, marginBottom: 18 },
  commandInput: { height: 51, borderRadius: 16, backgroundColor: colors.background, borderWidth: 1, borderColor: colors.border, flexDirection: 'row', alignItems: 'center', paddingLeft: 14, paddingRight: 7 },
  commandPlaceholder: { flex: 1, color: colors.textMuted, fontSize: 13 },
  voiceOrb: { width: 37, height: 37, borderRadius: 13, backgroundColor: colors.mint, justifyContent: 'center', alignItems: 'center' },
  voiceOrbText: { color: colors.black, fontSize: 17 },
  promptRow: { flexDirection: 'row', gap: 8, marginTop: 10 },
  promptChip: { flex: 1, minHeight: 44, borderRadius: 13, backgroundColor: '#203229', flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7 },
  promptChipText: { color: colors.mint, fontSize: 10, fontWeight: '700' },
  promptChipArrow: { color: colors.mint, fontSize: 11 },
  demoButton: { minHeight: 58, marginTop: 10, borderRadius: 15, borderWidth: 1, borderColor: '#3A5549', backgroundColor: '#13251D', paddingHorizontal: 13, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  demoEyebrow: { color: colors.textFaint, fontSize: 7, fontWeight: '800', letterSpacing: 1.1 },
  demoButtonText: { color: colors.text, fontSize: 11, fontWeight: '700', marginTop: 4 },
  demoArrow: { color: colors.mint, fontSize: 19 },
  metricsRow: { flexDirection: 'row', gap: 8, marginBottom: 27 },
  metricCard: { flex: 1, minHeight: 79, borderRadius: 16, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, padding: 12, justifyContent: 'center' },
  metricValue: { fontSize: 22, fontWeight: '800' },
  metricLabel: { color: colors.textMuted, fontSize: 9, lineHeight: 13, marginTop: 4 },
  sectionHeading: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 2, marginBottom: 11 },
  sectionTitle: { color: colors.textMuted, fontSize: 10, fontWeight: '800', letterSpacing: 1.45 },
  sectionAction: { color: colors.mintStrong, fontSize: 9, fontWeight: '800', letterSpacing: 0.8 },
  nextCard: { borderRadius: 17, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, padding: 14, flexDirection: 'row', alignItems: 'center', marginBottom: 25 },
  nextTime: { width: 61 },
  nextTimeText: { color: colors.text, fontSize: 11, fontWeight: '700' },
  nextLine: { width: 3, height: 39, borderRadius: 3, backgroundColor: colors.mint, marginRight: 13 },
  nextCopy: { flex: 1 },
  nextTitle: { color: colors.text, fontSize: 14, fontWeight: '700' },
  nextMeta: { color: colors.textMuted, fontSize: 10, marginTop: 5 },
  chevron: { color: colors.textMuted, fontSize: 25 },
  taskGroup: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, borderRadius: 17, paddingHorizontal: 13, marginBottom: 10 },
  taskRow: { minHeight: 65, flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1, borderBottomColor: '#1F3129', gap: 11 },
  taskRowPressed: { opacity: 0.7, transform: [{ scale: 0.995 }] },
  taskCheck: { width: 22, height: 22, borderWidth: 1.5, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  taskCheckDone: { backgroundColor: colors.mint },
  taskCheckMark: { color: colors.black, fontSize: 13, fontWeight: '900' },
  taskCopy: { flex: 1 },
  taskTitle: { color: colors.text, fontSize: 13, fontWeight: '600' },
  taskTitleDone: { color: colors.textFaint, textDecorationLine: 'line-through' },
  taskMeta: { color: colors.textMuted, fontSize: 9, marginTop: 5 },
  taskCategory: { width: 4, height: 25, borderRadius: 4 },
  captureButton: { height: 44, borderRadius: 14, borderWidth: 1, borderStyle: 'dashed', borderColor: colors.border, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7, marginBottom: 22 },
  capturePlus: { color: colors.mint, fontSize: 17 },
  captureButtonText: { color: colors.textMuted, fontSize: 11, fontWeight: '600' },
  nudgeCard: { borderRadius: 17, borderWidth: 1, borderColor: '#5A4C2B', backgroundColor: '#1C1B13', padding: 14, flexDirection: 'row', alignItems: 'center', gap: 12 },
  nudgeIcon: { color: colors.yellow, fontSize: 21 },
  nudgeCopy: { flex: 1 },
  nudgeLabel: { color: colors.yellow, fontSize: 9, fontWeight: '800', letterSpacing: 1.2 },
  nudgeText: { color: '#CBC4AF', fontSize: 10, lineHeight: 15, marginTop: 4 },
  assistantPage: { flex: 1 },
  assistantHeader: { paddingHorizontal: 20, paddingTop: 18, paddingBottom: 13, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderBottomWidth: 1, borderBottomColor: '#17251F' },
  screenTitle: { color: colors.text, fontSize: 30, fontWeight: '700', letterSpacing: -0.8, marginTop: 6 },
  onlineBadge: { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: '#173022', borderRadius: 12, paddingHorizontal: 10, paddingVertical: 7 },
  onlineBadgeDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.mintStrong },
  onlineBadgeText: { color: colors.mint, fontSize: 8, letterSpacing: 1, fontWeight: '800' },
  chat: { flex: 1 },
  chatContent: { width: '100%', maxWidth: 620, alignSelf: 'center', paddingHorizontal: 20, paddingTop: 18, paddingBottom: 16 },
  messageStack: { alignItems: 'flex-start', marginBottom: 17, width: '100%' },
  userStack: { alignItems: 'flex-end' },
  messageIdentity: { flexDirection: 'row', alignItems: 'center', gap: 7, marginBottom: 7 },
  smallMark: { width: 22, height: 22, borderRadius: 8, backgroundColor: colors.mint, alignItems: 'center', justifyContent: 'center' },
  smallMarkText: { color: colors.black, fontSize: 11 },
  messageIdentityText: { color: colors.textMuted, fontSize: 8, fontWeight: '800', letterSpacing: 1.1 },
  messageBubble: { maxWidth: '88%', borderRadius: 17, paddingHorizontal: 14, paddingVertical: 11 },
  assistantBubble: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, borderTopLeftRadius: 5 },
  userBubble: { backgroundColor: colors.mint, borderBottomRightRadius: 5 },
  messageText: { color: colors.text, fontSize: 13, lineHeight: 19 },
  userMessageText: { color: colors.black },
  thinkingRow: { flexDirection: 'row', alignItems: 'center', gap: 9, paddingVertical: 8 },
  thinkingText: { color: colors.textMuted, fontSize: 11 },
  suggestionRow: { paddingHorizontal: 20, paddingVertical: 8, gap: 8 },
  suggestionChip: { minHeight: 44, borderWidth: 1, borderColor: colors.border, borderRadius: 14, backgroundColor: colors.surface, paddingHorizontal: 13, alignItems: 'center', justifyContent: 'center' },
  suggestionText: { color: colors.mint, fontSize: 10, fontWeight: '600' },
  composer: { minHeight: 57, marginHorizontal: 14, marginTop: 5, marginBottom: 8, borderRadius: 18, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, flexDirection: 'row', alignItems: 'center', paddingLeft: 8, paddingRight: 7 },
  dictationButton: { width: 38, height: 38, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  dictationIcon: { color: colors.mint, fontSize: 17 },
  composerInput: { flex: 1, maxHeight: 100, color: colors.text, fontSize: 13, paddingVertical: 13 },
  sendButton: { width: 39, height: 39, borderRadius: 13, backgroundColor: colors.mint, alignItems: 'center', justifyContent: 'center' },
  sendButtonDisabled: { opacity: 0.3 },
  sendButtonText: { color: colors.black, fontSize: 21, fontWeight: '800' },
  actionCard: { width: '100%', borderRadius: 18, borderWidth: 1, backgroundColor: colors.surfaceRaised, padding: 14, marginTop: 10 },
  actionHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 12 },
  actionIcon: { width: 31, height: 31, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  actionIconText: { fontSize: 15 },
  actionLabel: { fontSize: 8, fontWeight: '900', letterSpacing: 1.25 },
  dismissButton: { marginLeft: 'auto', width: 28, height: 28, alignItems: 'center', justifyContent: 'center' },
  dismissButtonText: { color: colors.textMuted, fontSize: 21 },
  actionTitle: { color: colors.text, fontSize: 15, fontWeight: '700' },
  actionDetail: { color: colors.textMuted, fontSize: 10, marginTop: 5 },
  emailPreview: { backgroundColor: colors.background, borderRadius: 12, padding: 11, marginTop: 11 },
  emailPreviewText: { color: colors.textMuted, fontSize: 10, lineHeight: 16 },
  actionButton: { minHeight: 46, borderRadius: 13, backgroundColor: colors.mint, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 13 },
  actionButtonDone: { backgroundColor: '#274334' },
  actionButtonText: { color: colors.black, fontSize: 11, fontWeight: '800' },
  actionButtonArrow: { color: colors.black, fontSize: 16 },
  dismissedCard: { width: '100%', borderRadius: 14, borderWidth: 1, borderColor: colors.border, padding: 12, marginTop: 8 },
  dismissedText: { color: colors.textFaint, fontSize: 10, textAlign: 'center' },
  dayHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 22 },
  planButton: { borderRadius: 13, backgroundColor: colors.mint, paddingHorizontal: 13, paddingVertical: 10 },
  planButtonText: { color: colors.black, fontSize: 10, fontWeight: '800' },
  daySummary: { flexDirection: 'row', borderRadius: 18, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, padding: 17, marginBottom: 27 },
  summaryValue: { color: colors.text, fontSize: 25, fontWeight: '800' },
  summaryLabel: { color: colors.textMuted, fontSize: 9, marginTop: 4 },
  summaryDivider: { width: 1, backgroundColor: colors.border, marginHorizontal: 37 },
  timeline: { marginBottom: 25 },
  timelineRow: { minHeight: 64, flexDirection: 'row', alignItems: 'center' },
  timelineTime: { width: 66, color: colors.textMuted, fontSize: 10 },
  timelineBar: { width: 3, height: 42, borderRadius: 3, marginRight: 13 },
  timelineEvent: { flex: 1 },
  timelineTitle: { color: colors.text, fontSize: 13, fontWeight: '700' },
  timelineMeta: { color: colors.textMuted, fontSize: 9, marginTop: 5 },
  profileCard: { marginTop: 25, marginBottom: 27, borderRadius: 18, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, padding: 14, flexDirection: 'row', alignItems: 'center', gap: 12 },
  largeAvatar: { width: 47, height: 47, borderRadius: 16, backgroundColor: colors.mint, alignItems: 'center', justifyContent: 'center' },
  largeAvatarText: { color: colors.black, fontSize: 18, fontWeight: '900' },
  profileCopy: { flex: 1 },
  profileName: { color: colors.text, fontSize: 14, fontWeight: '700' },
  profileSub: { color: colors.textMuted, fontSize: 9, marginTop: 5 },
  settingsGroup: { borderRadius: 18, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, paddingHorizontal: 14, marginBottom: 27 },
  settingRow: { minHeight: 90, flexDirection: 'row', alignItems: 'center', gap: 11 },
  settingIcon: { width: 37, height: 37, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  settingCopy: { flex: 1 },
  settingTitle: { color: colors.text, fontSize: 12, fontWeight: '700' },
  settingDescription: { color: colors.textMuted, fontSize: 9, lineHeight: 14, marginTop: 4 },
  settingDivider: { height: 1, backgroundColor: '#203129' },
  connectionRow: { minHeight: 74, flexDirection: 'row', alignItems: 'center', gap: 11 },
  connectionLogo: { width: 37, height: 37, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  connectionLogoText: { fontSize: 14, fontWeight: '900' },
  connectButton: { minHeight: 44, backgroundColor: colors.mint, borderRadius: 12, paddingHorizontal: 11, alignItems: 'center', justifyContent: 'center' },
  connectedButton: { backgroundColor: '#243D31', borderWidth: 1, borderColor: '#3B654E' },
  connectButtonText: { color: colors.black, fontSize: 9, fontWeight: '800' },
  connectedButtonText: { color: colors.mint },
  engineCard: { borderRadius: 18, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, padding: 15, marginBottom: 13 },
  engineTop: { flexDirection: 'row', alignItems: 'center', gap: 11 },
  engineMark: { color: colors.mint, fontSize: 22 },
  engineTitle: { color: colors.text, fontSize: 12, fontWeight: '700' },
  engineSub: { color: colors.mintStrong, fontSize: 9, marginTop: 4 },
  engineBody: { color: colors.textMuted, fontSize: 9, lineHeight: 15, marginTop: 13 },
  safetyCard: { borderRadius: 16, borderWidth: 1, borderColor: '#584A2B', backgroundColor: '#1B1A13', padding: 14 },
  safetyLabel: { color: colors.yellow, fontSize: 8, fontWeight: '800', letterSpacing: 1.2 },
  safetyText: { color: '#C8C0AA', fontSize: 9, lineHeight: 15, marginTop: 7 },
  emptyState: { minHeight: 145, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 24 },
  emptyStateIcon: { color: colors.mint, fontSize: 24, marginBottom: 9 },
  emptyStateTitle: { color: colors.text, fontSize: 13, fontWeight: '700' },
  emptyStateDetail: { color: colors.textMuted, fontSize: 10, lineHeight: 15, textAlign: 'center', marginTop: 5 },
  bottomNav: { height: 78, borderTopWidth: 1, borderTopColor: '#1E3028', backgroundColor: '#0B1511', paddingTop: 7, paddingBottom: 8, flexDirection: 'row', justifyContent: 'space-around' },
  navItem: { width: 68, alignItems: 'center', justifyContent: 'center', gap: 3 },
  navIcon: { width: 35, height: 29, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  navIconActive: { backgroundColor: colors.mint },
  navIconText: { color: colors.textMuted, fontSize: 18 },
  navIconTextActive: { color: colors.black },
  navLabel: { color: colors.textMuted, fontSize: 8, fontWeight: '600' },
  navLabelActive: { color: colors.mint },
  modalBackdrop: { flex: 1, backgroundColor: '#00000099', justifyContent: 'flex-end' },
  captureSheet: { backgroundColor: colors.surfaceRaised, borderTopLeftRadius: 28, borderTopRightRadius: 28, padding: 20, paddingBottom: Platform.OS === 'ios' ? 35 : 20, borderTopWidth: 1, borderColor: colors.border },
  sheetHandle: { width: 39, height: 4, borderRadius: 3, backgroundColor: colors.border, alignSelf: 'center', marginBottom: 22 },
  sheetEyebrow: { color: colors.mint, fontSize: 9, fontWeight: '800', letterSpacing: 1.4 },
  sheetTitle: { color: colors.text, fontSize: 22, fontWeight: '700', marginTop: 7, marginBottom: 17 },
  captureInput: { height: 52, borderRadius: 15, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.background, paddingHorizontal: 14, color: colors.text, fontSize: 13 },
  primaryButton: { height: 49, borderRadius: 15, backgroundColor: colors.mint, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 9, marginTop: 12 },
  primaryButtonText: { color: colors.black, fontSize: 12, fontWeight: '800' },
  primaryButtonIcon: { color: colors.black, fontSize: 17 },
});
