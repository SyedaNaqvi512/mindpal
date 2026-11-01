import 'package:flutter/material.dart';

import '../models/exercise_catalog.dart';
import '../models/exercise_logic.dart';
import '../services/exercise_controller.dart';
import '../widgets/breathing_bubble.dart';
import '../widgets/safe_text_field.dart';
import 'step_kit.dart';

/// The shorter guided activities and the grounding exercises.

// FR-39 Breathing Bubble, alone.
List<ExerciseStep> breathingSteps() => [
      ExerciseStep(
        title: 'Breathe',
        build: (context, c) => Column(
          children: [
            const Prompt(
                'Follow the bubble. Breathe in as it grows, pause, breathe out as '
                'it shrinks, and pause. Go at a pace that feels comfortable.'),
            Center(
              child: BreathingBubble(
                cycles: 4,
                onFinished: () => c.set('breaths', 4),
              ),
            ),
          ],
        ),
      ),
    ];

// FR-70 5-4-3-2-1 Grounding.
List<ExerciseStep> groundingSteps() => [
      tapStep(
        title: '5 things you can see',
        prompt: 'Look around slowly. Tap a circle each time you notice something you can see.',
        key: 'see',
        count: 5,
        noun: 'thing you see',
        noteLabel: 'Optional note: what did you see?',
      ),
      tapStep(
        title: '4 things you can feel',
        prompt: 'Notice four things you can feel, such as your feet on the floor or the chair under you.',
        key: 'feel',
        count: 4,
        noun: 'thing you feel',
        noteLabel: 'Optional note: what did you feel?',
      ),
      tapStep(
        title: '3 things you can hear',
        prompt: 'Listen for three sounds, near or far.',
        key: 'hear',
        count: 3,
        noun: 'sound you hear',
        noteLabel: 'Optional note: what did you hear?',
      ),
      tapStep(
        title: '2 things you can smell',
        prompt: 'Notice two things you can smell. If nothing stands out, imagine a smell you like.',
        key: 'smell',
        count: 2,
        noun: 'smell',
        noteLabel: 'Optional note: what did you smell?',
      ),
      tapStep(
        title: '1 thing you can taste',
        prompt: 'Notice one thing you can taste, or take a sip of water and notice it.',
        key: 'taste',
        count: 1,
        noun: 'taste',
        noteLabel: 'Optional note: what did you taste?',
      ),
      infoStep(
        title: 'Back in the room',
        body: 'You have taken a moment to notice the world around you. Take one '
            'more slow breath before you carry on.',
      ),
    ];

// FR-40 Thought Record.
List<ExerciseStep> thoughtRecordSteps() => [
      textStep(
        title: 'The situation',
        prompt: 'What was happening? Who was there, where, and when?',
        key: 'situation',
        label: 'The situation',
      ),
      thoughtStep(prompt: 'What went through your mind? Write the thought as it sounded.'),
      chipsStep(
        title: 'How you felt',
        prompt: 'Tap the feelings that fit. You can pick more than one.',
        key: 'feelings',
        options: const [
          'Anxious', 'Sad', 'Angry', 'Ashamed', 'Overwhelmed', 'Stressed',
          'Lonely', 'Guilty', 'Hopeful', 'Calm', 'Tired', 'Other',
        ],
      ),
      sliderStep(
        title: 'How strong was it?',
        prompt: 'Slide to show how strong the feeling was.',
        key: 'intensity',
        lowLabel: '0  Barely there',
        highLabel: '100  Very strong',
      ),
      ExerciseStep(
        title: 'Evidence for the thought',
        canContinue: (c) => c.list('for').isNotEmpty,
        build: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Prompt('What makes this thought seem true? Add one item at a time.'),
            ItemListEditor(
              items: c.list('for'),
              label: 'Evidence for',
              onChanged: (v) => c.set('for', v),
            ),
          ],
        ),
      ),
      ExerciseStep(
        title: 'Evidence against the thought',
        canContinue: (c) => c.list('against').isNotEmpty,
        build: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Prompt('What does not fit the thought, or points another way?'),
            ItemListEditor(
              items: c.list('against'),
              label: 'Evidence against',
              onChanged: (v) => c.set('against', v),
            ),
          ],
        ),
      ),
    ];

// FR-40 Gratitude Reflection.
List<ExerciseStep> gratitudeSteps() => [
      chipsStep(
        title: 'Things to appreciate',
        prompt: 'Tap three things, or more, from today that you appreciate.',
        key: 'things',
        options: const [
          'A person who helped me', 'A good meal', 'Some rest', 'Time outdoors',
          'A kind word', 'Something I finished', 'Music', 'A quiet moment',
          'My own effort', 'Something that made me laugh',
        ],
      ),
      textStep(
        title: 'Why it matters',
        prompt: 'Pick one of them, or something else, and write why it matters to you.',
        key: 'why',
        label: 'Why it matters',
      ),
      textStep(
        title: 'Carry it with you',
        prompt: 'Write one sentence you would like to remember from today.',
        key: 'carry',
        label: 'One sentence',
        maxLines: 2,
      ),
    ];

// FR-40 Self-Compassion Reflection.
List<ExerciseStep> selfCompassionSteps() => [
      textStep(
        title: 'Something hard',
        prompt: 'What is hard for you right now? A few words are enough.',
        key: 'hard',
        label: 'What is hard',
      ),
      chipsStep(
        title: 'Notice what you feel',
        prompt: 'Tap the feelings that are here. Noticing them is enough.',
        key: 'feelings',
        options: const [
          'Worried', 'Sad', 'Frustrated', 'Disappointed', 'Embarrassed',
          'Tired', 'Alone', 'Pressured',
        ],
      ),
      tapStep(
        title: 'You are not alone',
        prompt: 'Many people feel this way at times. Finding something hard '
            'does not mean something is wrong with you. Tap the circle when '
            'you have read this.',
        key: 'ack',
        count: 1,
        noun: 'reading',
      ),
      textStep(
        title: 'A kind sentence',
        prompt: 'Imagine a good friend felt this way. What kind thing would you '
            'say to them? Now write it to yourself.',
        key: 'kind',
        label: 'A kind sentence to myself',
      ),
    ];

// FR-40 Problem-Solving.
List<ExerciseStep> problemSolvingSteps() => [
      textStep(
        title: 'The problem',
        prompt: 'Describe the problem in one or two sentences.',
        key: 'problem',
        label: 'The problem',
      ),
      ExerciseStep(
        title: 'Possible options',
        canContinue: (c) => c.list('options').isNotEmpty,
        build: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Prompt('List a few things you could do. They do not have to be perfect.'),
            ItemListEditor(
              items: c.list('options'),
              label: 'An option',
              onChanged: (v) => c.set('options', v),
            ),
          ],
        ),
      ),
      ExerciseStep(
        title: 'Choose one',
        canContinue: (c) => c.text('chosen').isNotEmpty,
        build: (context, c) {
          final options = c.list('options');
          if (options.isEmpty) {
            return const Prompt('No options were added. You can skip this step.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Prompt('Tap the option that feels most doable right now.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in options)
                    ChoiceChip(
                      label: Text(o),
                      selected: c.text('chosen') == o,
                      onSelected: (_) => c.set('chosen', o),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      textStep(
        title: 'A small first step',
        prompt: 'What is one small thing you can do to begin?',
        key: 'first',
        label: 'My first step',
        maxLines: 3,
      ),
      chipsStep(
        title: 'When',
        prompt: 'When would you like to take that step?',
        key: 'when',
        options: const ['Today', 'This week', 'When I feel ready'],
        multi: false,
      ),
    ];

// FR-40 Daily Check-In.
List<ExerciseStep> checkInSteps() => [
      sliderStep(
        title: 'Mood',
        prompt: 'How is your mood today?',
        key: 'mood',
        lowLabel: 'Very low',
        highLabel: 'Very good',
        showNumber: false,
      ),
      sliderStep(
        title: 'Energy',
        prompt: 'How much energy do you have today?',
        key: 'energy',
        lowLabel: 'Very little',
        highLabel: 'A lot',
        showNumber: false,
      ),
      chipsStep(
        title: 'In a few words',
        prompt: 'Tap the words that describe today so far.',
        key: 'words',
        options: const [
          'Calm', 'Busy', 'Anxious', 'Hopeful', 'Tired', 'Focused', 'Sad',
          'Grateful', 'Stressed', 'Okay',
        ],
      ),
      textStep(
        title: 'A short note',
        prompt: 'Anything else on your mind today? This is optional.',
        key: 'note',
        label: 'Note',
        maxLines: 3,
      ),
    ];

// FR-71 STOP.
List<ExerciseStep> stopSteps() => [
      tapStep(
        title: 'S: Stop',
        prompt: 'Pause whatever you are doing. Let your hands rest. Tap the circle when you have stopped.',
        key: 's',
        count: 1,
        noun: 'stop',
      ),
      tapStep(
        title: 'T: Take a breath',
        prompt: 'Take one slow breath in and a slow breath out. Tap the circle when you have breathed.',
        key: 't',
        count: 1,
        noun: 'breath',
      ),
      chipsStep(
        title: 'O: Observe',
        prompt: 'What do you notice? Tap what is there.',
        key: 'observe',
        options: const [
          'Thoughts', 'Feelings', 'My body', 'Sounds around me', 'Tension',
          'Something else',
        ],
      ),
      chipsStep(
        title: 'P: Proceed',
        prompt: 'What would help you proceed with kindness toward yourself?',
        key: 'proceed',
        options: const [
          'Carry on slowly', 'Ask for help', 'Take a short walk', 'Drink some water',
          'Write in my journal', 'Do one small task',
        ],
      ),
      infoStep(
        title: 'A gentle close',
        body: 'You paused, breathed, noticed what is here and chose a way to '
            'continue. You can come back to this whenever you need a moment.',
      ),
    ];

const List<String> kAnchorPhrases = [
  'This moment will pass.',
  'I am doing the best I can.',
  'One breath at a time.',
  'I can take this one step at a time.',
  'I am safe in this moment.',
  'It is okay to feel what I feel.',
];

// FR-72 Anchoring phrase. A written phrase is stored encrypted on the device.
List<ExerciseStep> anchorSteps() => [
      ExerciseStep(
        title: 'Choose a phrase',
        canContinue: (c) => c.text('phrase').trim().isNotEmpty,
        build: (context, c) {
          final chosen = c.text('phrase');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Prompt('Tap a calming phrase, or write your own below.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in kAnchorPhrases)
                    ChoiceChip(
                      label: Text(p),
                      selected: chosen == p,
                      onSelected: (_) {
                        c.data['_phraseN'] = c.intOf('_phraseN') + 1;
                        c.set('phrase', p);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SafeTextField(
                key: ValueKey('phrase-${c.intOf('_phraseN')}'),
                initial: chosen,
                label: 'Or write your own phrase',
                maxLines: 2,
                maxLength: 120,
                onChanged: (v) => c.set('phrase', v),
              ),
              const SizedBox(height: 8),
              const Prompt('A phrase you write is saved encrypted on this phone.',
                  muted: true),
            ],
          );
        },
      ),
      ExerciseStep(
        title: 'Read it as you breathe',
        build: (context, c) => Column(
          children: [
            const Prompt('Read your phrase slowly, again and again, while the circle breathes with you.'),
            Center(
              child: BreathingBubble(
                cycles: 4,
                caption: c.text('phrase'),
                onFinished: () => c.set('anchored', true),
              ),
            ),
          ],
        ),
      ),
    ];

// FR-73 Body scan: at most 5 minutes, text only, no audio.
List<ExerciseStep> bodyScanSteps() => [
      for (final a in kBodyScanAreas)
        infoStep(title: a.$1, body: a.$2, seconds: a.$3),
    ];

/// Used by tests: the exercises whose steps are in this file.
const Set<String> kSimpleExerciseIds = {
  ExerciseIds.breathing,
  ExerciseIds.grounding,
  ExerciseIds.thoughtRecord,
  ExerciseIds.gratitude,
  ExerciseIds.selfCompassion,
  ExerciseIds.problemSolving,
  ExerciseIds.checkIn,
  ExerciseIds.stop,
  ExerciseIds.anchor,
  ExerciseIds.bodyScan,
};

