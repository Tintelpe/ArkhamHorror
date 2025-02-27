<script lang="ts" setup>
import AbilityButton from '@/arkham/components/AbilityButton.vue'
import Question from '@/arkham/components/Question.vue';
import { computed } from 'vue';
import { ChaosBag } from '@/arkham/types/ChaosBag';
import { Game } from '@/arkham/types/Game';
import { SkillTest } from '@/arkham/types/SkillTest';
import { AbilityLabel, AbilityMessage, Message } from '@/arkham/types/Message'
import Draggable from '@/components/Draggable.vue';
import Card from '@/arkham/components/Card.vue'
import CommittedSkills from '@/arkham/components/CommittedSkills.vue';
import { MessageType, StartSkillTestButton } from '@/arkham/types/Message';
import * as ArkhamGame from '@/arkham/types/Game';
import { imgsrc, replaceIcons } from '@/arkham/helpers';
import ChaosBagView from '@/arkham/components/ChaosBag.vue';
// has a slot for content

const props = defineProps<{
  game: Game
  skillTest: SkillTest
  chaosBag: ChaosBag
  playerId: string
}>()

const skills = computed(() => {
  const { skillTest } = props
  const normalizeSkill = (skill: string) => {
    switch (skill) {
      case 'SkillWillpower': return 'willpower'
      case 'SkillIntellect': return 'intellect'
      case 'SkillCombat': return 'combat'
      case 'SkillAgility': return 'agility'
      default: return skill
    }
  }
  return skillTest.skills.map(normalizeSkill)
})
const skillTestResults = computed(() => props.game.skillTestResults)
const emit = defineEmits(['choose'])
const committedCards = computed(() => props.skillTest.committedCards)
const choices = computed(() => ArkhamGame.choices(props.game, props.playerId))
const skipTriggersAction = computed(() => choices.value.findIndex((c) => c.tag === MessageType.SKIP_TRIGGERS_BUTTON))
const investigatorPortrait = computed(() => {
  const choice = choices.value.find((c): c is StartSkillTestButton => c.tag === MessageType.START_SKILL_TEST_BUTTON)
  if (choice) {
    const player = props.game.investigators[choice.investigatorId]

    if (player.isYithian) {
      return imgsrc(`portraits/${choice.investigatorId.replace('c', '')}.jpg`)
    }

    return imgsrc(`portraits/${player.cardCode.replace('c', '')}.jpg`)
  }

  if (props.skillTest) {
    const player = props.game.investigators[props.skillTest.investigator]

    if (player.isYithian) {
      return imgsrc(`portraits/${props.skillTest.investigator.replace('c', '')}.jpg`)
    }

    return imgsrc(`portraits/${player.cardCode.replace('c', '')}.jpg`)
  }

  return null;
})

function isAbility(v: Message): v is AbilityLabel {
  if ("ability" in v) {
    const ability = v.ability
    if ("source" in ability) {
      const { source } = ability

      if (source.sourceTag === 'ProxySource') {
        return source.source.tag === 'SkillTestSource'
      }
    }
  }

  return false
}

const abilities = computed<AbilityMessage[]>(() => {
  return choices.value
    .reduce<AbilityMessage[]>((acc, v, i) =>
      isAbility(v) ? [...acc, { contents: v, displayAsAction: false, index: i}] : acc
    , [])
})


async function choose(idx: number) {
  emit('choose', idx)
}

const targetCard = computed(() => {
  if (!props.skillTest.targetCard) return null
  return props.game.cards[props.skillTest.targetCard]
})

const sourceCard = computed(() => {
  if (!props.skillTest.sourceCard) return null
  if (props.skillTest.sourceCard === props.skillTest.targetCard) return null
  return props.game.cards[props.skillTest.sourceCard]
})

const applyResultsAction = computed(() => {
  return choices.value.findIndex((c) => c.tag === "SkillTestApplyResultsButton");
})

const skillValue = computed(() => {
  const result = skillTestResults.value
  if (result !== null) {
    const {skillTestResultsSkillValue, skillTestResultsIconValue, skillTestResultsChaosTokensValue } = result
    return skillTestResultsSkillValue + skillTestResultsIconValue + skillTestResultsChaosTokensValue
  } else {
    return props.skillTest.modifiedSkillValue
  }
})

const testResult = computed(() => {
  const result = skillTestResults.value
  if (result !== null) {
    const {skillTestResultsDifficulty} = result
    return skillValue.value - skillTestResultsDifficulty
  } else {
    return null
  }
})

const label = function(body: string) {
  if (body.startsWith("$")) {
    return t(body.slice(1))
  }
  return replaceIcons(body).replace(/_([^_]*)_/g, '<b>$1</b>').replace(/\*([^*]*)\*/g, '<i>$1</i>')
}

</script>

<template>
  <Teleport to="body">
    <Draggable>
      <template #handle>
        <h2>Skill Test</h2>
      </template>
      <div class="skill-test">
        <div class="steps">
          <div v-tooltip="'Determine skill of test. Skill test of that type begins.'" class="step" :class="{ active: skillTest.step === 'DetermineSkillOfTestStep' }">ST.1</div>
          <div v-tooltip="'Commit cards from hand to skill test.'" class="step" :class="{ active: skillTest.step === 'CommitCardsFromHandToSkillTestStep' }">ST.2</div>
          <div v-tooltip="'Reveal chaos token.'" class="step" :class="{ active: skillTest.step === 'RevealChaosTokenStep' }">ST.3</div>
          <div v-tooltip="'Resolve chaos symbol effect(s).'" class="step" :class="{ active: skillTest.step === 'ResolveChaosSymbolEffectsStep' }">ST.4</div>
          <div v-tooltip="'Determine investigator\'s modified skill value.'" class="step" :class="{ active: skillTest.step === 'DetermineInvestigatorsModifiedSkillValueStep' }">ST.5</div>
          <div v-tooltip="'Determine success/failure of skill test.'" class="step" :class="{ active: skillTest.step === 'DetermineSuccessOrFailureOfSkillTestStep' }">ST.6</div>
          <div v-tooltip="'Apply skill test results.'" class="step" :class="{ active: skillTest.step === 'ApplySkillTestResultsStep' }">ST.7</div>
          <div v-tooltip="'Skill test ends.'" class="step" :class="{ active: skillTest.step === 'SkillTestEndsStep' }">ST.8</div>
        </div>
        <div class="skill-test-contents">
          <Card v-if="targetCard" :game="game" :card="targetCard" class="target-card" :revealed="true" playerId="" />
          <div class="test-status">
            <div class="test-difficulty">
              <span class="difficulty">{{skillTest.modifiedDifficulty}}</span>
            </div>
            <div class="vs">
              <div v-if="skills.length > 0" class="skills">
                <div v-for="(skill, idx) in skills" :key="idx" :class="`${skill}-icon ${skill}-skill`">
                  <span>{{skill}}</span>
                </div>
              </div>
              <div v-else-if="skillTest.baseValue.tag === 'HalfResourcesOf'" class="half-resources">
                <img :src="imgsrc(`resource.png`)" /> / 2
              </div>
              <span>VS</span>
            </div>
            <div class="modified-skill">
              <span class="skill">{{skillValue}}</span>
            </div>
          </div>
          <img
            v-if="investigatorPortrait"
            class="portrait"
            :src="investigatorPortrait"
          />
          <Card v-if="sourceCard" :game="game" :card="sourceCard" :revealed="true" playerId="" />
        </div>
        <ChaosBagView
          :game="game"
          :chaosBag="chaosBag"
          :skillTest="skillTest"
          :playerId="playerId"
          @choose="choose"
        />
        <div v-if="committedCards.length > 0" class="committed-skills" key="committed-skills">
          <div class="skills-container">
            <CommittedSkills
              :game="game"
              :cards="committedCards"
              :playerId="playerId"
              @choose="$emit('choose', $event)"
            />
          </div>
          <h2>Committed Skills</h2>
        </div>

        <AbilityButton
          v-for="ability in abilities"
          :key="ability.index"
          :ability="ability.contents"
          :tooltipIsButtonText="true"
          @click="choose(ability.index)"
          />

        <div v-if="skillTestResults" class="skill-test-results" :class="{ success: skillTestResults.skillTestResultsSuccess, failure: !skillTestResults.skillTestResultsSuccess}">
          <span v-if="skillTestResults.skillTestResultsSuccess">
            Succeeded by {{testResult}}
          </span>
          <span v-else-if="testResult !== null">
            Failed by {{testResult - (skillTestResults.skillTestResultsResultModifiers || 0)}}
          </span>
        </div>

        <div v-if="skillTestResults" class="skill-test-results-break"></div>
        <button
          v-if="skipTriggersAction !== -1"
          @click="$emit('choose', skipTriggersAction)"
          class="skip-triggers-button"
        >Skip Triggers</button>
        <Question :game="game" :playerId="playerId" @choose="choose" :isSkillTest="true" />
        <button
          class="apply-results"
          v-if="applyResultsAction !== -1"
          @click="choose(applyResultsAction)"
        >Apply Results</button>
      </div>
    </Draggable>
  </Teleport>
</template>

<style scoped lang="scss">
.skill-test {
  background: #759686;
  width: fit-content;
  text-align: center;
  z-index: 10;
  overflow: hidden;
}

.skill-test-contents {
  padding: 10px;
  display: flex;
  gap: 5px;
  color: white;
  background-color: rgb(0, 0, 0, 0.6);
}

.test-status {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 30px;
  padding: 0 30px;
  text-transform: uppercase;
}

.test-difficulty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
}

.difficulty {
  background-color: darkred;
  color: white;
  font-weight: bold;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 50%;
}

.skill {
  background-color: darkgreen;
  color: white;
  font-weight: bold;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 50%;
}

.modified-skill {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
}

.portrait {
  width: var(--card-width);
  height: auto;
  border-radius: 5px;
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
  margin-right: calc(var(--card-width) + 5px);

  &:has(+ .card-container) {
    margin-right: 0;
  }
}

.committed-skills {
  background: #333;

  h2 {
    background: #111;
    color: #666;
    text-transform: uppercase;
    margin: 0
  }
}

.skills-container {
  padding: 10px;
}

.skill-test-results {
  padding: 10px;
  text-align: left;
}

.skill-test-results-break {
  flex-basis: 100%;
  height: 0;
}

.apply-results {
  width: 100%;
  border: 0;
  text-align: center;
  text-transform: uppercase;
  transition: all 0.3s ease-in;
  border: 0;
  padding: 10px;
  background-color: #532e61;
  color: #EEE;
}

button {
  width: 100%;
  border: 0;
  text-align: center;
  text-transform: uppercase;
  transition: all 0.2s ease-in;
  border: 0;
  padding: 10px;
  background-color: darken($select, 30%);
  &:hover {
    background-color: darken($select, 20%);
  }
  color: #EEE;
}

.success {
  background-color: darkgreen;
  text-transform: uppercase;
  text-align: center;
  color: white;
}

.failure {
  background-color: darkred;
  text-transform: uppercase;
  text-align: center;
  color: white;
}

i {
  font-family: 'Arkham';
  font-style: normal;
  font-weight: normal;
  font-variant: normal;
  text-transform: none;
  line-height: 1;
  -webkit-font-smoothing: antialiased;
  position: relative;
}

i.iconSkull {
  &:before {
    font-family: "Arkham";
    content: "\004E";
  }
}

i.iconCultist {
  &:before {
    font-family: "Arkham";
    content: "\0042";
  }
}

i.iconTablet {
  &:before {
    font-family: "Arkham";
    content: "\0056";
  }
}

i.iconElderThing {
  &:before {
    font-family: "Arkham";
    content: "\0043";
  }
}

i.iconSkillWillpower {
  &:before {
    font-family: "Arkham";
    content: "\0041";
  }
}

i.iconSkillIntellect {
  &:before {
    font-family: "Arkham";
    content: "\0046";
  }
}

i.iconSkillCombat {
  &:before {
    font-family: "Arkham";
    content: "\0044";
  }
}

i.iconSkillAgility {
  &:before {
    font-family: "Arkham";
    content: "\0053";
  }
}

.button {
  display: inline-block;
  padding: 5px 10px;
  margin: 2px;
  background-color: #333;
  color: white;
  border: 1px solid #666;
  cursor: pointer;

  &:hover {
    background-color: #111;
  }

  &:active {
    background-color: #666;
    border-color: #111;
  }

  flex: 1;
}

.skill-test :deep(.choices) {
  display: flex;
  width: 100%;
  padding: 0;
  margin: 0;
  box-sizing: border-box;
  gap: 0;
  font-size: 0.7em;

  .message-label {
    flex: 1;
    margin: 0;
  }

  button {
    display: block;
    border: 0;
    text-align: left;
    text-transform: uppercase;
    transition: all 0.2s ease-in;
    border: 0;
    padding: 10px;
    margin: 0 !important;
    box-sizing: border-box;
    border-radius: 0;
    background-color: darken($select, 30%);
    &:hover {
      background-color: darken($select, 20%);
    }
    color: #EEE;
  }
}


.message-label {
  flex: 1;
}

.vs {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
}

.steps {
  display: flex;
  flex-direction: row;
  width: 100%;

  .step {
    flex: 1;
    text-align: center;
  }

  .step:nth-child(odd) {
    background: rgba(0, 0, 0, 0.4);
    color: white;
  }

  .step:nth-child(even) {
    background: rgba(0, 0, 0, 0.2);
    color: white;
  }

  .step.active {
    background: rgba(255, 0, 255, 0.5);
  }

}

.willpower-skill {
  color: var(--willpower);
  background: var(--willpower-light);
}

.intellect-skill {
  color: var(--intellect);
  background: var(--intellect-light);
}

.combat-skill {
  color: var(--combat);
  background: var(--combat-light);
}

.agility-skill {
  color: var(--agility);
  background: var(--agility-light);
}

.willpower-skill, .intellect-skill, .combat-skill, .agility-skill {
  font-size: 1.5em;
  width:1.2em;
  height:1.2em;
  line-height: 1.2em;
  border-radius: 50%;
}

.willpower-skill span, .intellect-skill span, .combat-skill span, .agility-skill span {
  display: none;
}

.target-card {
  margin-left: calc(var(--card-width) + 5px);
}

.skills {
  display: flex;
  flex-direction: row;
  gap: 5px;
}

.half-resources {
  img {
    width: 30px;
  }
  align-items: center;
  display: flex;
  gap: 5px;
}
</style>
