import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../exercises/models/exercise_logic.dart';

/// FR-64 to FR-69: the Learn articles. They are bundled with the app, so they
/// work offline, need no server, use no AI and store nothing about the reader.
/// All wording is original. No study is quoted; if one is ever added, its
/// source must be named in the article.

enum BlockKind { heading, paragraph, bullets }

class Block {
  const Block.heading(this.text)
      : kind = BlockKind.heading,
        items = const [];
  const Block.paragraph(this.text)
      : kind = BlockKind.paragraph,
        items = const [];
  const Block.bullets(this.items)
      : kind = BlockKind.bullets,
        text = '';

  final BlockKind kind;
  final String text;
  final List<String> items;
}

/// A button shown at the end of an article.
enum LearnAction { none, breathing, support }

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.icon,
    required this.blocks,
    this.action = LearnAction.none,
  });

  final String id;
  final String title;
  final String summary;
  final int minutes;
  final IconData icon;
  final List<Block> blocks;
  final LearnAction action;
}

/// FR-68: every article ends with this note.
const String kNotTherapyNote =
    'MindPal is not therapy. It is a self-help tool and cannot diagnose, treat '
    'or replace support from a qualified professional.';

/// FR-67: the breathing session is five minutes long (25 breaths of 12 s).
const int kLearnBreathSeconds = 300;
const int kLearnBreathCycles = kLearnBreathSeconds ~/ kBreathCycleSeconds;

const List<Article> kArticles = [
  Article(
    id: 'what-is-mindfulness',
    title: 'What mindfulness is',
    summary: 'Paying attention to now, with a kind and curious mind.',
    minutes: 2,
    icon: Symbols.spa_rounded,
    blocks: [
      Block.paragraph(
          'Mindfulness means noticing what is happening in this moment: the '
          'thoughts passing through your head, the feelings in your body, the '
          'sounds around you. The aim is simply to notice, without rushing to '
          'decide whether any of it is good or bad.'),
      Block.heading('A skill, not a mood'),
      Block.paragraph(
          'Mindfulness is something you practise, like stretching or learning '
          'a song. It is not a special state you have to reach. Minds wander '
          'all the time. Noticing that yours has wandered, and coming back, '
          'is the practice itself.'),
      Block.heading('What it is not'),
      Block.bullets([
        'It is not emptying your mind or stopping your thoughts.',
        'It is not forcing yourself to feel calm.',
        'It is not a test you can fail.',
      ]),
      Block.heading('A small example'),
      Block.paragraph(
          'Next time you drink something warm, give it your full attention for '
          'a few sips. Feel the cup, notice the smell, the first taste. When '
          'your mind drifts to your to-do list, that is fine. Gently bring it '
          'back to the cup.'),
    ],
  ),
  Article(
    id: 'why-it-may-help',
    title: 'Why it may help',
    summary: 'What people often notice when they pause and pay attention.',
    minutes: 2,
    icon: Symbols.favorite_rounded,
    blocks: [
      Block.paragraph(
          'Many people find that stopping for a minute to notice how they feel '
          'may help them feel calmer. Experiences differ, and some people find '
          'it hard or even uncomfortable at first. That is common and it is '
          'okay.'),
      Block.heading('Things people often describe'),
      Block.bullets([
        'Spotting stress earlier, such as a tight jaw or a racing mind.',
        'A small gap between a feeling and what they do next.',
        'More awareness of what tends to set off a hard day.',
        'A kinder way of talking to themselves.',
      ]),
      Block.heading('How this fits with journaling'),
      Block.paragraph(
          'Writing an entry is already a way of paying attention. When you '
          'write how you feel and why, you are noticing your own mind, which '
          'is the same skill mindfulness builds. Over time your history can '
          'show you patterns you would not see in a single day.'),
      Block.heading('A fair note'),
      Block.paragraph(
          'MindPal does not claim that mindfulness will treat, prevent or cure '
          'any condition, and this article does not quote studies. Treat it '
          'as something you can try and see whether it suits you.'),
    ],
  ),
  Article(
    id: 'mindfulness-and-reframing',
    title: 'Mindfulness and reframing',
    summary: 'How noticing a thought helps you look at it more fairly.',
    minutes: 3,
    icon: Symbols.psychology_alt_rounded,
    blocks: [
      Block.paragraph(
          'The reflections and exercises in MindPal borrow an idea from '
          'cognitive behavioural therapy (CBT): the way we read a situation '
          'affects how we feel about it. Reframing means looking at a thought '
          'again and asking whether there is a fairer way to see it.'),
      Block.heading('Two steps that work together'),
      Block.bullets([
        'Notice. Mindfulness helps you catch the thought as it appears, '
            'instead of being carried along by it.',
        'Examine. Reframing asks what the thought is based on and whether '
            'other views are possible.',
      ]),
      Block.heading('Where you will see this in MindPal'),
      Block.bullets([
        'Your reflection asks gentle questions about an entry you wrote.',
        'The Facts or Assumptions exercise helps you sort what you know from '
            'what you are guessing.',
        'The Thought Record and Belief Rating exercises walk through a '
            'thought one step at a time.',
      ]),
      Block.heading('You stay in charge'),
      Block.paragraph(
          'A reflection is a prompt to help you think, not advice about what '
          'to do. You can ignore any part that does not fit. You know your '
          'life better than any app does.'),
    ],
  ),
  Article(
    id: 'simple-ways-to-practise',
    title: 'Simple ways to practise',
    summary: 'Three small practices you can do in a minute or two.',
    minutes: 3,
    icon: Symbols.self_improvement_rounded,
    action: LearnAction.breathing,
    blocks: [
      Block.paragraph(
          'You do not need a quiet room or special cushions. Pick one of '
          'these, try it for a minute, and see how it feels. Short and '
          'regular is better than long and rare.'),
      Block.heading('Breathing'),
      Block.paragraph(
          'Let your breathing be slow and easy. Follow one breath in and one '
          'breath out. If your mind wanders, that is normal. Notice it and '
          'return to the next breath. There is no need to breathe in any '
          'special way.'),
      Block.heading('Body'),
      Block.paragraph(
          'Move your attention slowly from your feet up to your head. Notice '
          'where your body touches the chair or floor, and where it feels '
          'tight or loose. You are only observing, not fixing anything.'),
      Block.heading('Surroundings'),
      Block.paragraph(
          'Look around and quietly name a few things you can see, hear and '
          'feel. This brings your attention out of your head and into the '
          'room you are in.'),
      Block.heading('Try it now'),
      Block.paragraph(
          'The button below opens a breathing bubble that grows and shrinks '
          'for five minutes. Stop whenever you like.'),
    ],
  ),
  Article(
    id: 'not-therapy-and-help',
    title: 'Not therapy, and when to get help',
    summary: 'What MindPal can and cannot do, and who to reach out to.',
    minutes: 2,
    icon: Symbols.volunteer_activism_rounded,
    action: LearnAction.support,
    blocks: [
      Block.paragraph(
          'Mindfulness and journaling can be a gentle part of looking after '
          'yourself. They are not a replacement for a doctor, a counsellor or '
          'a therapist, and MindPal cannot diagnose or treat anything.'),
      Block.heading('Consider talking to someone if'),
      Block.bullets([
        'A low or anxious mood lasts for weeks, or keeps getting worse.',
        'Sleep, eating or daily tasks are becoming hard to manage.',
        'You feel unable to cope, or things feel hopeless.',
        'You have thoughts of harming yourself.',
      ]),
      Block.heading('Who you can reach out to'),
      Block.paragraph(
          'A friend or family member you trust, your doctor, a counsellor at '
          'your university, or a mental health service. If you are in '
          'immediate danger, contact your local emergency services right '
          'away.'),
      Block.heading('It is okay to stop'),
      Block.paragraph(
          'Paying close attention can sometimes bring up difficult feelings. '
          'If that happens, you can stop any exercise at any time and do '
          'something that feels safer, such as speaking with someone you '
          'trust.'),
    ],
  ),
];

Article? articleById(String id) {
  for (final a in kArticles) {
    if (a.id == id) return a;
  }
  return null;
}
