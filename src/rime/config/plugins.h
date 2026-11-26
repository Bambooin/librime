//
// Copyright RIME Developers
// Distributed under the BSD License
//
#ifndef RIME_CONFIG_PLUGINS_H_
#define RIME_CONFIG_PLUGINS_H_

#include <rime/common.h>

namespace rime {

class ConfigCompiler;
struct ConfigResource;

class ConfigCompilerPlugin {
 public:
  using Review = bool(ConfigCompiler* compiler, an<ConfigResource> resource);

  virtual ~ConfigCompilerPlugin() = default;

  virtual bool ReviewCompileOutput(ConfigCompiler* compiler,
                                   an<ConfigResource> resource) = 0;
  virtual bool ReviewLinkOutput(ConfigCompiler* compiler,
                                an<ConfigResource> resource) = 0;
};

class AutoPatchConfigPlugin : public ConfigCompilerPlugin {
 public:
  bool ReviewCompileOutput(ConfigCompiler* compiler,
                           an<ConfigResource> resource) override;
  bool ReviewLinkOutput(ConfigCompiler* compiler,
                        an<ConfigResource> resource) override;
};

class DefaultConfigPlugin : public ConfigCompilerPlugin {
 public:
  bool ReviewCompileOutput(ConfigCompiler* compiler,
                           an<ConfigResource> resource) override;
  bool ReviewLinkOutput(ConfigCompiler* compiler,
                        an<ConfigResource> resource) override;
};

class LegacyPresetConfigPlugin : public ConfigCompilerPlugin {
 public:
  bool ReviewCompileOutput(ConfigCompiler* compiler,
                           an<ConfigResource> resource) override;
  bool ReviewLinkOutput(ConfigCompiler* compiler,
                        an<ConfigResource> resource) override;
};

class LegacyDictionaryConfigPlugin : public ConfigCompilerPlugin {
 public:
  bool ReviewCompileOutput(ConfigCompiler* compiler,
                           an<ConfigResource> resource) override;
  bool ReviewLinkOutput(ConfigCompiler* compiler,
                        an<ConfigResource> resource) override;
};

class BuildInfoPlugin : public ConfigCompilerPlugin {
 public:
  bool ReviewCompileOutput(ConfigCompiler* compiler,
                           an<ConfigResource> resource) override;
  bool ReviewLinkOutput(ConfigCompiler* compiler,
                        an<ConfigResource> resource) override;
};

class ResourceResolver;
struct ResourceType;

class SaveOutputPlugin : public ConfigCompilerPlugin {
 public:
  SaveOutputPlugin();
  ~SaveOutputPlugin() override;

  bool ReviewCompileOutput(ConfigCompiler* compiler,
                           an<ConfigResource> resource) override;
  bool ReviewLinkOutput(ConfigCompiler* compiler,
                        an<ConfigResource> resource) override;

 private:
  the<ResourceResolver> resource_resolver_;
};

}  // namespace rime

#endif  // RIME_CONFIG_PLUGINS_H_
