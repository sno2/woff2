const std = @import("std");

const version: std.SemanticVersion = .{ .major = 1, .minor = 0, .patch = 2 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_clis = b.option(bool, "enable_clis", "Build cli tools") orelse false;
    const enable_tests = b.option(bool, "enable_tests", "Enable tests") orelse false;
    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information") orelse false;
    const sanitize_thread = b.option(bool, "sanitize_thread", "Enable thread sanitizer") orelse false;

    const brotli = b.dependency("brotli", .{
        .linkage = linkage,
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .sanitize_thread = sanitize_thread,
    });

    const mod_options: std.Build.Module.CreateOptions = .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .strip = strip,
        .sanitize_thread = sanitize_thread,
    };

    const flags = &.{"-std=c++11"};

    const woff2_common_mod = b.createModule(mod_options);
    woff2_common_mod.linkLibrary(brotli.artifact("brotlicommon"));
    woff2_common_mod.linkLibrary(brotli.artifact("brotlienc"));
    woff2_common_mod.linkLibrary(brotli.artifact("brotlidec"));
    woff2_common_mod.addCMacro("__STDC_FORMAT_MACROS", "");
    if (target.result.os.tag.isDarwin()) {
        woff2_common_mod.addCMacro("OS_MACOSX", "");
    }
    woff2_common_mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "table_tags.cc",
            "variable_length.cc",
            "woff2_common.cc",
        },
        .flags = flags,
    });

    const woff2_common = b.addLibrary(.{
        .linkage = linkage,
        .name = "woff2common",
        .root_module = woff2_common_mod,
        .version = version,
    });
    b.installArtifact(woff2_common);
    woff2_common.installHeader(b.path("include/woff2/output.h"), "woff2/output.h");

    const woff2_dec_mod = b.createModule(mod_options);
    woff2_dec_mod.linkLibrary(brotli.artifact("brotlicommon"));
    woff2_dec_mod.linkLibrary(brotli.artifact("brotlidec"));
    woff2_dec_mod.linkLibrary(woff2_common);
    woff2_dec_mod.addIncludePath(b.path("include"));
    woff2_dec_mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "woff2_dec.cc",
            "woff2_out.cc",
        },
        .flags = flags,
    });

    const woff2_dec = b.addLibrary(.{
        .linkage = linkage,
        .name = "woff2dec",
        .root_module = woff2_dec_mod,
        .version = version,
    });
    b.installArtifact(woff2_dec);
    woff2_dec.installHeader(b.path("include/woff2/decode.h"), "woff2/decode.h");

    const woff2_enc_mod = b.createModule(mod_options);
    woff2_enc_mod.linkLibrary(brotli.artifact("brotlicommon"));
    woff2_enc_mod.linkLibrary(brotli.artifact("brotlienc"));
    woff2_enc_mod.linkLibrary(woff2_common);
    woff2_enc_mod.addIncludePath(b.path("include"));
    woff2_enc_mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "font.cc",
            "glyph.cc",
            "normalize.cc",
            "transform.cc",
            "woff2_enc.cc",
        },
        .flags = flags,
    });

    const woff2_enc = b.addLibrary(.{
        .linkage = linkage,
        .name = "woff2enc",
        .root_module = woff2_enc_mod,
        .version = version,
    });
    b.installArtifact(woff2_enc);
    woff2_enc.installHeader(b.path("include/woff2/encode.h"), "woff2/encode.h");

    const test_step = b.step("test", "Test woff2 compress/decompress against IBMPlexSans; requires -Denable_clis");
    if (enable_clis) {
        const woff2_decompress_mod = b.createModule(mod_options);
        woff2_decompress_mod.linkLibrary(woff2_common);
        woff2_decompress_mod.linkLibrary(woff2_dec);
        woff2_decompress_mod.addCSourceFile(.{
            .file = b.path("src/woff2_decompress.cc"),
            .flags = flags,
        });

        const woff2_decompress = b.addExecutable(.{
            .name = "woff2_decompress",
            .root_module = woff2_decompress_mod,
            .version = version,
        });
        b.installArtifact(woff2_decompress);

        const woff2_compress_mod = b.createModule(mod_options);
        woff2_compress_mod.linkLibrary(woff2_common);
        woff2_compress_mod.linkLibrary(woff2_enc);
        woff2_compress_mod.addCSourceFile(.{
            .file = b.path("src/woff2_compress.cc"),
            .flags = flags,
        });

        const woff2_compress = b.addExecutable(.{
            .name = "woff2_compress",
            .root_module = woff2_compress_mod,
            .version = version,
        });
        b.installArtifact(woff2_compress);

        const woff2_info_mod = b.createModule(mod_options);
        woff2_info_mod.linkLibrary(woff2_common);
        woff2_info_mod.addCSourceFile(.{
            .file = b.path("src/woff2_info.cc"),
            .flags = flags,
        });

        const woff2_info = b.addExecutable(.{
            .name = "woff2_info",
            .root_module = woff2_info_mod,
            .version = version,
        });
        b.installArtifact(woff2_info);

        if (enable_tests) {
            const test_ttf = b.addExecutable(.{
                .name = "test_ttf",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("build/test_ttf.zig"),
                    .target = target,
                    .optimize = optimize,
                }),
            });

            if (b.lazyDependency("ibm_plex_sans", .{})) |ibm_plex_sans| {
                const ttfs: []const []const u8 = &.{
                    "IBMPlexSans-BoldItalic.ttf",
                    "IBMPlexSans-Bold.ttf",
                    "IBMPlexSans-ExtraLightItalic.ttf",
                    "IBMPlexSans-ExtraLight.ttf",
                    "IBMPlexSans-Italic.ttf",
                    "IBMPlexSans-LightItalic.ttf",
                    "IBMPlexSans-Light.ttf",
                    "IBMPlexSans-MediumItalic.ttf",
                    "IBMPlexSans-Medium.ttf",
                    "IBMPlexSans-Regular.ttf",
                    "IBMPlexSans-SemiBoldItalic.ttf",
                    "IBMPlexSans-SemiBold.ttf",
                    "IBMPlexSans-TextItalic.ttf",
                    "IBMPlexSans-Text.ttf",
                    "IBMPlexSans-ThinItalic.ttf",
                    "IBMPlexSans-Thin.ttf",
                };

                const tmp = b.addWriteFiles();

                for (ttfs) |ttf| {
                    const ttf_copy = tmp.addCopyFile(ibm_plex_sans.path(b.fmt("fonts/complete/ttf/{s}", .{ttf})), ttf);
                    const run_test = b.addRunArtifact(test_ttf);
                    run_test.addArtifactArg(woff2_compress);
                    run_test.addArtifactArg(woff2_info);
                    run_test.addArtifactArg(woff2_decompress);
                    run_test.addFileArg(ttf_copy);
                    test_step.dependOn(&run_test.step);
                }
            }
        } else {
            test_step.dependOn(&b.addFail("-Denable_tests is required to run tests").step);
        }
    } else {
        test_step.dependOn(&b.addFail("-Denable_clis is required to run tests").step);
    }
}
