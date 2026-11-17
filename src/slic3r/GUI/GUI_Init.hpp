#ifndef slic3r_GUI_Init_hpp_
#define slic3r_GUI_Init_hpp_

#include <libslic3r/Preset.hpp>
#include <libslic3r/PrintConfig.hpp>
#include <vector>
#include <utility>
#include <string>

namespace Slic3r {

namespace GUI {

struct OpenGLVersions
{
    static const std::vector<std::pair<int, int>> core;
};

struct GUI_InitParams
{
	int		                    argc;
	char	                  **argv;

	// Substitutions of unknown configuration values done during loading of user presets.
	PresetsConfigSubstitutions  preset_substitutions;

    std::vector<std::string>    load_configs;
    std::vector<std::string>    load_filaments;
    DynamicPrintConfig          extra_config;
    std::vector<std::string>    input_files;

    std::pair<int, int>         opengl_version                  { 0, 0 };
    bool                        opengl_debug                    { false };
    bool                        opengl_compatibility_profile    { false };

    //BBS: remove start_as_gcodeviewer logic
	//bool	                    start_as_gcodeviewer;
	bool                        input_gcode { false };

    // Explicit ORTO production context passed by the CLI launcher.
    std::string                 orto_mode;
    std::string                 orto_algorithm;
    std::string                 orto_request_number;
    std::string                 orto_request_id;
    std::string                 orto_printer_id;
    std::string                 orto_request_item_id;
    std::string                 orto_request_unit_id;
    std::string                 orto_job_id;
    std::string                 orto_output_dir;
};

int GUI_Run(GUI_InitParams &params);

} // namespace GUI
} // namespace Slic3r

#endif // slic3r_GUI_Init_hpp_
