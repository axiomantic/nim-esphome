## `nim_esphome/freertos`: FreeRTOS task coordination and synchronization.
##
## Provides clean abstractions for managing FreeRTOS tasks (e.g. suspending
## computationally intensive tasks or inference engines during flash writes
## to avoid cache panics on ESP32).

import api

when defined(esp32) or defined(freertos):
  type
    TaskHandle* = pointer

  proc xTaskGetHandle(pcNameToQuery: cstring): TaskHandle {.importc: "xTaskGetHandle", header: "<freertos/FreeRTOS.h>", cdecl.}
  proc vTaskSuspend(xTaskToSuspend: TaskHandle) {.importc: "vTaskSuspend", header: "<freertos/task.h>", cdecl.}
  proc vTaskResume(xTaskToResume: TaskHandle) {.importc: "vTaskResume", header: "<freertos/task.h>", cdecl.}

  proc getTaskHandle*(name: string): TaskHandle =
    ## Queries FreeRTOS for the handle corresponding to task `name`.
    xTaskGetHandle(name.cstring)

  proc suspendTask*(name: string): bool =
    ## Suspends the named FreeRTOS task if running.
    ## Returns true if the task handle was found and suspended.
    let task = xTaskGetHandle(name.cstring)
    if task != nil:
      info("FreeRTOS", "Suspending task '" & name & "'...")
      vTaskSuspend(task)
      return true
    false

  proc resumeTask*(name: string): bool =
    ## Resumes the named FreeRTOS task if currently suspended.
    ## Returns true if the task handle was found and resumed.
    let task = xTaskGetHandle(name.cstring)
    if task != nil:
      info("FreeRTOS", "Resuming task '" & name & "'...")
      vTaskResume(task)
      return true
    false

else:
  type
    TaskHandle* = pointer

  var mockSuspendedTasks*: seq[string] = @[]

  proc getTaskHandle*(name: string): TaskHandle =
    cast[TaskHandle](1)

  proc suspendTask*(name: string): bool =
    info("FreeRTOS", "Host simulated: suspending task '" & name & "'")
    if name notin mockSuspendedTasks:
      mockSuspendedTasks.add(name)
    true

  proc resumeTask*(name: string): bool =
    info("FreeRTOS", "Host simulated: resuming task '" & name & "'")
    let idx = mockSuspendedTasks.find(name)
    if idx >= 0:
      mockSuspendedTasks.delete(idx)
    true
