//
// Copyright RIME Developers
// Distributed under the BSD License
//
#include <filesystem>

#include <gtest/gtest.h>

#include <rime/config.h>
#include <rime_api.h>
#include <rime_levers_api.h>

namespace {

constexpr const char* kConfigId = "customize_bool_test";
constexpr const char* kConfigFile = "customize_bool_test.custom.yaml";

}  // namespace

// In the default API flavor Bool is int. Ensure customize_bool() selects the
// bool overload of ConfigValue so the value is stored as "true"/"false" and
// can later be read back with GetBool().
TEST(RimeLeversApiTest, CustomizeBoolPersistsBoolean) {
  namespace fs = std::filesystem;
  (void)fs::remove(kConfigFile);

  RimeApi* rime = rime_get_api();
  ASSERT_NE(rime, nullptr);
  RimeModule* module = rime->find_module("levers");
  ASSERT_NE(module, nullptr);
  auto* levers = reinterpret_cast<RimeLeversApi*>(module->get_api());
  ASSERT_NE(levers, nullptr);
  ASSERT_TRUE(RIME_API_AVAILABLE(levers, custom_settings_init));
  ASSERT_TRUE(RIME_API_AVAILABLE(levers, customize_bool));
  ASSERT_TRUE(RIME_API_AVAILABLE(levers, save_settings));

  RimeCustomSettings* settings =
      levers->custom_settings_init(kConfigId, "rime_test");
  ASSERT_NE(settings, nullptr);
  ASSERT_TRUE(levers->customize_bool(settings, "test_bool", True) != False);
  EXPECT_TRUE(levers->save_settings(settings) != False);
  levers->custom_settings_destroy(settings);

  rime::Config config;
  ASSERT_TRUE(config.LoadFromFile(rime::path(kConfigFile)));
  bool value = false;
  ASSERT_TRUE(config.GetBool("patch/test_bool", &value));
  EXPECT_TRUE(value);

  (void)fs::remove(kConfigFile);
}
