*** Comments ***
The gauntlet: every hostile image must be refused.

After `alr build`, `python3 tools/pack.py` and `python3 tools/attack.py`:

    renode-test tests/gauntlet.robot

On the untouched seed, the three tests tagged `baseline` pass. Every other
attack FAILS, because the seed bootloader lets it through. Turning this
file green is the project.

*** Settings ***
Suite Setup       Gauntlet Setup
Suite Teardown    Teardown
Test Setup        Reset Emulation
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${SLOT_A}         0x08040000
${VERDICT}        anchor: slot A verdict=(\\w+)

*** Keywords ***
Gauntlet Setup
    [Documentation]    Locate the repository. Forward slashes on every OS, for Renode.
    Setup
    ${root}=    Evaluate    pathlib.Path(r"""${CURDIR}""").parent.as_posix()    modules=pathlib
    Set Suite Variable    ${ROOT}       ${root}
    Set Suite Variable    ${BOOT}       ${root}/bin/anchor
    Set Suite Variable    ${GOOD}       ${root}/build/slot_a.img
    Set Suite Variable    ${ATTACKS}    ${root}/build/attacks

Power On With Slot A
    [Documentation]    Fresh board, bootloader in place, ${image} written in slot A.
    [Arguments]    ${image}
    Execute Command    mach create "anchor"
    Execute Command    machine LoadPlatformDescription @${ROOT}/renode/anchor.repl
    Execute Command    sysbus LoadELF @${BOOT}
    IF    $image != 'NONE'
        Execute Command    sysbus LoadBinary @${image} ${SLOT_A}
    END
    Create Terminal Tester    sysbus.usart1    timeout=5
    Start Emulation

Verdict For Slot A
    ${line}=    Wait For Line On Uart    ${VERDICT}    treatAsRegex=true
    RETURN    ${line.groups[0]}

Must Be Rejected
    [Documentation]    The bootloader must refuse the image and must not start it.
    [Arguments]    ${attack}
    Power On With Slot A    ${ATTACKS}/${attack}.img
    ${verdict}=    Verdict For Slot A
    Should Not Be Equal    ${verdict}    ACCEPTED
    ...    msg=The bootloader accepted a hostile image (${attack}).    values=False
    Wait For Line On Uart    anchor: no bootable image

*** Test Cases ***
Good Image Boots
    [Tags]    baseline
    Power On With Slot A    ${GOOD}
    ${verdict}=    Verdict For Slot A
    Should Be Equal    ${verdict}    ACCEPTED
    Wait For Line On Uart    hello: firmware version 1
    Wait For Line On Uart    hello: tick 1

Empty Slot Does Not Boot
    [Tags]    baseline
    Power On With Slot A    NONE
    Wait For Line On Uart    anchor: no bootable image

Attack: Bad Magic
    [Tags]    baseline
    Must Be Rejected    bad_magic

Attack: Flipped Payload Bit
    Must Be Rejected    flipped_payload_bit

Attack: Unsigned
    Must Be Rejected    unsigned

Attack: Signed With The Wrong Key
    Must Be Rejected    wrong_key

Attack: Version Edited After Signing
    Must Be Rejected    edited_version

Attack: Payload Size Overflow
    Must Be Rejected    size_overflow

Attack: Built For Another Device
    Must Be Rejected    wrong_device
