#if defined _l4d_transition_entity_included_
	#endinput
#endif
#define _l4d_transition_entity_included_

/**
 * @brief Called when a weapon/spawner/prop in checkpoint is being saved for next level.
 * @note Weapons owned by player are not included.
 * 
 * @param entity		Transitioning entity index
 *
 * @noreturn
 */
forward void L4D_OnEntityTransitioning(int entity);

/**
 * @brief Called when a weapon/spawner/prop is restored from the previous level (Post-spawned)
 * @note Weapons owned by player are not included.
 * @note This will be called after the level-transitioning
 * @note This will be called once the level failed and restarted.
 * @note Chance that the entity is marked for deletion if for some reason something bad happens during restore.
 * 
 * @param entity		New entity index
 * @param oldindex		Old entity index in last level
 *
 * @noreturn
 */
forward void L4D_OnEntityTransitioned(int entity, int oldindex);


public SharedPlugin __pl_l4d_transition_entity = 
{
	name = "l4d_transition_entity",
	file = "l4d_transition_entity.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d_transition_entity_SetNTVOptional()
{
}
#endif
