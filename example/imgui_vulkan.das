//options log, log_infer_passes

options persistent_heap = true

require daslib/safe_addr
require daslib/vulkan_boost
require daslib/vulkan_simple_app
require daslib/defer
require math
require strings

require imgui
require imgui_app
require imgui_demo
require imgui_vulkan


def imgui_vulkan_app(title : string; blk : block<(c : CommandBuffer)>)
    var app <- SimpleVulkanApp(title, 1920, 1080,
        VkPresentModeKHR VK_PRESENT_MODE_MAILBOX_KHR
        //VkPresentModeKHR VK_PRESENT_MODE_FIFO_KHR
    )
    defer <| { delete app; }

    CreateContext(null)
    GetIO().FontGlobalScale = 2.0;   // BBATKIN: note - my monitor is HUGE
    StyleColorsDark(null)
    ImGui_ImplGlfw_InitForVulkan(app |> glfw_window, true)

    var init_info <- [[ImGui_ImplVulkan_InitInfo
        Instance        = app |> vk_instance,
        PhysicalDevice  = app |> vk_phys_dev,
        Device          = app |> vk_device,
        QueueFamily     = app |> vk_gfx_qfam,
        Queue           = app |> vk_queue,
        DescriptorPool  = app |> vk_desc_pool,
        MinImageCount   = 2u,
        ImageCount      = uint(app |> images_in_swapchain)
    ]]
    ImGui_ImplVulkan_Init(safe_addr(init_info), app |> vk_render_pass)

    app |> run_cmd_sync <| $(cmd : CommandBuffer)
        ImGui_ImplVulkan_CreateFontsTexture(boost_value_to_vk(cmd))
    ImGui_ImplVulkan_DestroyFontUploadObjects()

    app |> frame_loop <| $(cmd : CommandBuffer)
        ImGui_ImplVulkan_NewFrame()
        ImGui_ImplGlfw_NewFrame()
        blk |> invoke(cmd)
        ImGui_ImplVulkan_RenderDrawData(
            GetDrawData(), boost_value_to_vk(cmd), [[VkPipeline]])

    ImGui_ImplVulkan_Shutdown()
    ImGui_ImplGlfw_Shutdown()
    DestroyContext(null)


[export]
def main()
    unsafe
        string_heap_collect()
    let heap_on_start = heap_bytes_allocated()
    let string_heap_on_start = string_heap_bytes_allocated()

    imgui_vulkan_app("Testing IMGUI Vulkan") <| $(cmd : CommandBuffer)
        NewFrame()
        DasShowDemoWindow(null)
        Render()

    unsafe
        string_heap_collect()
    let heap_leaks = int(heap_bytes_allocated() - heap_on_start)
    let string_heap_leaks = int(string_heap_bytes_allocated()
        - string_heap_on_start)

    print("{heap_leaks} heap bytes have leaked\n")
    print("{string_heap_leaks} string heap bytes have leaked\n")
    assert(heap_leaks == 0)
    assert(string_heap_leaks == 0)
