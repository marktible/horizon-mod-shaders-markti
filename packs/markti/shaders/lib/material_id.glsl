#ifdef RADIANCE_ENTITIES
uniform int blockEntityId;
float blockMaterial(float vertexId, vec2 atlasUV) { return float(blockEntityId); }
#else
// Standard block.properties / mc_Entity interface supplied by Horizon.
float blockMaterial(float vertexId, vec2 atlasUV) { return max(vertexId, 0.0); }
#endif
