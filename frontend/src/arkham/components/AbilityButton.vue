<script lang="ts" setup>
import { computed } from 'vue';
import type { Cost } from '@/arkham/types/Cost';
import type { AbilityLabel, FightLabel, EvadeLabel, EngageLabel } from '@/arkham/types/Message';
import type { Ability } from '@/arkham/types/Ability';
import type { Action } from '@/arkham/types/Action';
import { MessageType } from '@/arkham/types/Message';
import { replaceIcons } from '@/arkham/helpers';

const props = withDefaults(defineProps<{
 ability: AbilityLabel | FightLabel | EvadeLabel | EngageLabel
 tooltipIsButtonText?: boolean
 showMove?: boolean
}>(), { tooltipIsButtonText: false, showMove: true })

const ability = computed<Ability | null>(() => "ability" in props.ability ? props.ability.ability : null)

const isButtonText = computed(() => {
  return (props.tooltipIsButtonText && tooltip.value) || (tooltip.value && tooltip.value.content == "Use True Magick")
})

const isAction = (action: Action) => {
  if (props.ability.tag === MessageType.ABILITY_LABEL) {
    if (props.ability.ability.displayAsAction ?? false) {
      return false
    }
  }

  if (props.ability.tag === MessageType.EVADE_LABEL) {
    return action === "Evade"
  }
  if (props.ability.tag === MessageType.FIGHT_LABEL) {
    return action === "Fight"
  }
  if (props.ability.tag === MessageType.ENGAGE_LABEL) {
    return action === "Engage"
  }

  if (ability.value) {
    const {tag} = ability.value.type
    if (tag !== "ActionAbility" && tag !== "ActionAbilityWithBefore" && tag !== "ActionAbilityWithSkill") {
      return false
    }
    const actions = ability.value.type.actions
    return actions.indexOf(action) !== -1
  }

  return false
}

function totalActionCost(cost: Cost) {
  if (cost.tag === "Costs") {
    return cost.contents.reduce((acc, v) => v.tag === "ActionCost" ? acc + v.contents : acc, 0)
  } else if (cost.tag === "ActionCost") {
    return cost.contents
  }

  return 0
}

const isInvestigate = computed(() => isAction("Investigate"))
const isFight = computed(() => isAction("Fight"))
const isEvade = computed(() => isAction("Evade"))
const isEngage = computed(() => isAction("Engage"))
const display = computed(() => !isAction("Move") || props.showMove)
const isSingleActionAbility = computed(() => {
  if (!ability.value) {
    return false
  }

  if (ability.value.type.tag !== "ActionAbility") {
    return false
  }

  const cost = ability.value.type.cost
  return totalActionCost(cost) === 1
})

const tooltip = computed(() => {
  const body = ability.value && ability.value.tooltip
  if (body) {
    const content = replaceIcons(body).replace(/_([^_]*)_/g, '<b>$1</b>')
    return { content, html: true }
  }

  return null
})

const isZeroedActionAbility = computed(() => {
  if (!ability.value) {
    return false
  }

  if (ability.value.type.tag !== "ActionAbility") {
    return false
  }

  const cost = ability.value.type.cost
  return totalActionCost(cost) === 0
})

const isDoubleActionAbility = computed(() => {
  if (!ability.value) {
    return false
  }

  if (ability.value.type.tag !== "ActionAbility") {
    return false
  }

  const cost = ability.value.type.cost
  return totalActionCost(cost) === 2
})

const isTripleActionAbility = computed(() => {
  if (!ability.value) {
    return false
  }

  if (ability.value.type.tag !== "ActionAbility") {
    return false
  }

  const cost = ability.value.type.cost
  return totalActionCost(cost) === 3
})

const isObjective = computed(() => ability.value && ability.value.type.tag === "Objective")
const isFastActionAbility = computed(() => ability.value && ability.value.type.tag === "FastAbility")
const isReactionAbility = computed(() => ability.value && ability.value.type.tag === "ReactionAbility")
const isForcedAbility = computed(() => ability.value && ability.value.type.tag === "ForcedAbility")
const isHaunted = computed(() => ability.value && ability.value.type.tag === "Haunted")

const isNeutralAbility = computed(() => !(isInvestigate.value || isFight.value || isEvade.value || isEngage.value))

const abilityLabel = computed(() => {
  // don't use isButtonText
  if (isButtonText.value) {
    return tooltip.value.content
  }

  if (props.ability.tag === MessageType.ABILITY_LABEL) {
    if (props.ability.ability.displayAsAction ?? false) {
      return ""
    }
  }

  if (props.ability.tag === MessageType.EVADE_LABEL) {
    return "Evade"
  }

  if (props.ability.tag === MessageType.FIGHT_LABEL) {
    return "Fight"
  }

  if (props.ability.tag === MessageType.ENGAGE_LABEL) {
    return "Engage"
  }

  if (isForcedAbility.value === true) {
    return "Forced"
  }

  if (isObjective.value === true) {
    return "Objective"
  }

  if (ability.value.type.tag === "CustomizationReaction") {
    return ability.value.type.label
  }

  if (ability.value.type.tag === "ConstantReaction") {
    return ability.value.type.label
  }

  if (ability.value.type.tag === "ServitorAbility") {
    return ability.value.type.action
  }

  if (isReactionAbility.value === true) {
    return ""
  }

  if (ability.value && (ability.value.type.tag === "ActionAbility" || ability.value.type.tag === "ActionAbilityWithBefore" || ability.value.type.tag === "ActionAbilityWithSkill")) {
    const { actions } = ability.value.type
    if (actions.length === 1) {
      return actions[0]
    }
  }

  if (isHaunted.value === true) {
    return "Haunted"
  }

  return ""
})

const classObject = computed(() => {
  if (isButtonText.value) {
    return {}
  }
  return {
    'zeroed-ability-button': isZeroedActionAbility.value && isNeutralAbility.value,
    'ability-button': isSingleActionAbility.value && isNeutralAbility.value,
    'double-ability-button': isDoubleActionAbility.value,
    'triple-ability-button': isTripleActionAbility.value,
    'fast-ability-button': isFastActionAbility.value,
    'reaction-ability-button': isReactionAbility.value,
    'forced-ability-button': isForcedAbility.value,
    'investigate-button': isInvestigate.value,
    'fight-button': isFight.value,
    'evade-button': isEvade.value,
    'engage-button': isEngage.value,
    'objective-button': isObjective.value,
  }
})
</script>

<template>
  <button
    v-if="display"
    class="button"
    :class="classObject"
    @click="$emit('choose', ability)"
    v-tooltip="!isButtonText && tooltip"
    >{{abilityLabel}}</button>
</template>

<style lang="scss" scoped>
.button{
  border: 0;
  margin-top: 2px;
  color: #fff;
  cursor: pointer;
  border-radius: 4px;
  background-color: #555;
  z-index: 1000;
  width: 100%;
  min-width: max-content;
}

.objective-button {
  background-color: #465550;
}

.investigate-button {
  background-color: #40263A;
  &:before {
    font-family: "arkham";
    content: "\0046";
    margin-right: 5px;
  }
}

.fight-button {
  background-color: #8F5B41;
  &:before {
    font-family: "Arkham";
    content: "\0044";
    margin-right: 5px;
  }
}

.evade-button {
  background-color: #576345;
  &:before {
    font-family: "Arkham";
    content: "\0053";
    margin-right: 5px;
  }
}

.engage-button {
  background-color: #555;
  &:before {
    font-family: "Arkham";
    content: "\0048";
    margin-right: 5px;
  }
}

.ability-button {
  background-color: #555;
  &:before {
    font-family: "arkham";
    content: "\0049";
    margin-right: 5px;
  }
}

.zeroed-ability-button {
  background-color: #555;
  &:before {
    font-family: "arkham";
    content: "\0049";
    margin-right: 5px;
    color: rgba(255, 255, 255, 0.5);
  }
}

.double-ability-button {
  background-color: #555;
  &:before {
    font-family: "arkham";
    content: "\0049\0049";
    margin-right: 5px;
  }
}

.triple-ability-button {
  background-color: #555;
  &:before {
    font-family: "arkham";
    content: "\0049\0049\0049";
    margin-right: 5px;
  }
}

.fast-ability-button {
  background-color: #555;
  &:before {
    font-family: "arkham";
    content: "\0075";
    margin-right: 5px;
  }
}

.forced-ability-button {
  background-color: #222;
  outline: 2px solid var(--select);
  color: #fff;
}

.reaction-ability-button {
  background-color: #A02ECB;
  &:before {
    font-family: "arkham";
    content: "\0059";
    margin-right: 5px;
  }
}

</style>
