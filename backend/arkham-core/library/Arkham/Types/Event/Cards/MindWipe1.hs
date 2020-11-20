{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Event.Cards.MindWipe1 where

import Arkham.Import

import Arkham.Types.Event.Attrs
import Arkham.Types.Event.Runner
import Arkham.Types.Trait

newtype MindWipe1 = MindWipe1 Attrs
  deriving newtype (Show, ToJSON, FromJSON)

mindWipe1 :: InvestigatorId -> EventId -> MindWipe1
mindWipe1 iid uuid = MindWipe1 $ baseAttrs iid uuid "01068"

instance HasModifiersFor env MindWipe1 where
  getModifiersFor = noModifiersFor

instance HasActions env MindWipe1 where
  getActions i window (MindWipe1 attrs) = getActions i window attrs

instance (EventRunner env) => RunMessage env MindWipe1 where
  runMessage msg e@(MindWipe1 attrs@Attrs {..}) = case msg of
    InvestigatorPlayEvent iid eid _ | eid == eventId -> do
      locationId <- asks (getId @LocationId iid)
      enemyIds <- asks $ setToList . getSet locationId
      nonEliteEnemyIds <- flip filterM enemyIds $ \enemyId -> do
        notElem Elite <$> getSet enemyId
      if null nonEliteEnemyIds
        then e <$ unshiftMessage (Discard (EventTarget eventId))
        else e <$ unshiftMessages
          [ chooseOne
            iid
            [ TargetLabel
                (EnemyTarget eid')
                [ CreateEffect
                    "01068"
                    Nothing
                    (EventSource eventId)
                    (EnemyTarget eid')
                ]
            | eid' <- nonEliteEnemyIds
            ]
          , Discard (EventTarget eid)
          ]
    _ -> MindWipe1 <$> runMessage msg attrs
