import { JsonDecoder } from 'ts.data.json';

export enum MessageType {
  RUN = 'Run',
  TAKE_RESOURCES = 'TakeResources',
  DRAW_CARDS = 'DrawCards',
  PLAY_CARD = 'PlayCard',
  INVESTIGATE = 'Investigate',
  END_TURN = 'ChooseEndTurn',
  START_SKILL_TEST = 'StartSkillTest',
  COMMIT_CARD = 'SkillTestCommitCard',
  UNCOMMIT_CARD = 'SkillTestUncommitCard',
  AFTER_DISCOVER_CLUES = 'AfterDiscoverClues',
  ADVANCE_ACT = 'AdvanceAct',
  MOVE = 'MoveAction',
  FIGHT_ENEMY = 'FightEnemy',
  EVADE_ENEMY = 'EvadeEnemy',
  CONTINUE = 'Continue',
  INVESTIGATOR_DAMAGE = 'InvestigatorDamage',
}

export interface Message {
  tag: MessageType;
  contents: any; // eslint-disable-line
}

export const messageTypeDecoder = JsonDecoder.oneOf<MessageType>(
  [
    JsonDecoder.isExactly('Run').then(() => JsonDecoder.constant(MessageType.RUN)),
    JsonDecoder.isExactly('TakeResources').then(() => JsonDecoder.constant(MessageType.TAKE_RESOURCES)),
    JsonDecoder.isExactly('DrawCards').then(() => JsonDecoder.constant(MessageType.DRAW_CARDS)),
    JsonDecoder.isExactly('PlayCard').then(() => JsonDecoder.constant(MessageType.PLAY_CARD)),
    JsonDecoder.isExactly('Investigate').then(() => JsonDecoder.constant(MessageType.INVESTIGATE)),
    JsonDecoder.isExactly('ChooseEndTurn').then(() => JsonDecoder.constant(MessageType.END_TURN)),
    JsonDecoder.isExactly('StartSkillTest').then(() => JsonDecoder.constant(MessageType.START_SKILL_TEST)),
    JsonDecoder.isExactly('SkillTestCommitCard').then(() => JsonDecoder.constant(MessageType.COMMIT_CARD)),
    JsonDecoder.isExactly('SkillTestUncommitCard').then(() => JsonDecoder.constant(MessageType.UNCOMMIT_CARD)),
    JsonDecoder.isExactly('AfterDiscoverClues').then(() => JsonDecoder.constant(MessageType.AFTER_DISCOVER_CLUES)),
    JsonDecoder.isExactly('AdvanceAct').then(() => JsonDecoder.constant(MessageType.ADVANCE_ACT)),
    JsonDecoder.isExactly('MoveAction').then(() => JsonDecoder.constant(MessageType.MOVE)),
    JsonDecoder.isExactly('FightEnemy').then(() => JsonDecoder.constant(MessageType.FIGHT_ENEMY)),
    JsonDecoder.isExactly('EvadeEnemy').then(() => JsonDecoder.constant(MessageType.EVADE_ENEMY)),
    JsonDecoder.isExactly('Continue').then(() => JsonDecoder.constant(MessageType.CONTINUE)),
    JsonDecoder.isExactly('InvestigatorDamage').then(() => JsonDecoder.constant(MessageType.INVESTIGATOR_DAMAGE)),
  ],
  'MessageType',
);

export const messageDecoder = JsonDecoder.object<Message>(
  {
    tag: messageTypeDecoder,
    contents: JsonDecoder.succeed,
  },
  'Message',
);
