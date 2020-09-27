//
//  main.m
//  Mach_test
//
//  Created by 易家杨 on 2020/9/27.
//  Copyright © 2020 易家杨. All rights reserved.
//
#import <mach/mach.h>
#import <mach/port.h>
#import <stdio.h>
#import <Foundation/Foundation.h>
#import <stdlib.h>
#import <pthread.h>
#import "mach_excUser.c"
#import "mach_excServer.c"



mach_port_t exc_port;
pthread_t thread;


boolean_t mach_exc_server(mach_msg_header_t *InHeaderP,mach_msg_header_t *OutHeaderP);

kern_return_t catch_mach_exception_raise_state(
                                               mach_port_t exc_port,
                                               exception_type_t exc_type,
                                               const mach_exception_data_t exc_data,
                                               mach_msg_type_number_t exec_data_count,
                                               int *flavor,
                                               const thread_state_t old_state,
                                               mach_msg_type_number_t old_stateCnt,
                                               thread_state_t new_state,
                                               mach_msg_type_number_t *new_stateCnt
                                               )
{
    printf("In catch_mach_exception_raise_state");
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise_state_identity(
                                                        mach_port_t exc_port,
                                                        mach_port_t thread_port,
                                                        mach_port_t task_port,
                                                        exception_type_t exc_type,
                                                        mach_exception_data_t exc_data,
                                                        mach_msg_type_number_t exc_data_count,
                                                        int * flavor, thread_state_t old_state,
                                                        mach_msg_type_number_t old_stateCnt,
                                                        thread_state_t new_state,
                                                        mach_msg_type_number_t *new_stateCnt
                                                        )
{

    printf("In catch_mach_exception_raise_state_identity");
    return KERN_FAILURE;
}


kern_return_t catch_mach_exception_raise(
                                         mach_port_t exc_port,
                                         mach_port_t thread_port,
                                         mach_port_t task_port,
                                         exception_type_t exc_type,
                                         mach_exception_data_t exc_data,
                                         mach_msg_type_number_t exc_data_count
                                         )
{
    printf("In catch_mach_exception_raise");
    return KERN_SUCCESS;
}

void *exc_handler_thread(void * _)
{
    for (; ;) {
        struct msg_t
        {
            mach_msg_header_t header;
            char data[1024];
        };
        
        //用于接收异常消息的缓冲区
        struct msg_t rcv_msg;
        
        //处理完成后返回的消息
        struct msg_t snd_msg;
        
        //开始读取异常消息
        kern_return_t kr = mach_msg(&rcv_msg.header,
                                    MACH_RCV_MSG, 0,
                                    sizeof(rcv_msg), exc_port,
                                    MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        
        if (kr != MACH_MSG_SUCCESS) {
            fprintf(stderr, "mach_msg rcv failde: %s",mach_error_string(kr));
            exit(1);
        }
        
        //对消息进行解码,并调用对应函数来处理异常信息
        //处理完成后将编码好的处理结果存放到snd_msg中
        if (mach_exc_server(&rcv_msg.header, &snd_msg.header) != TRUE) {
            fprintf(stderr, "mach_exc_server failde: %s",mach_error_string(kr));
            exit(1);
        }
        
        //将处理完的结果返回给系统
        kr = mach_msg(&snd_msg.header, MACH_SEND_MSG, snd_msg.header.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        
        if (kr != MACH_MSG_SUCCESS) {
            fprintf(stderr, "mach_msg send failde: %s",mach_error_string(kr));
            exit(1);
        }
    }
    return NULL;
}


void setup_exc_port()
{
    kern_return_t kr;
    //创建一个端口用于接收异常消息
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &exc_port);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "mach_port_allocate 失败,错误信息: %s",mach_error_string(kr));
        exit(1);
    }
    
    //为端口添加MACH_MSG_TYPE_MAKE_SEND权限
    kr = mach_port_insert_right(mach_task_self(), exc_port, exc_port, MACH_MSG_TYPE_MAKE_SEND);
    
    if (kr != KERN_SUCCESS) {
           fprintf(stderr, "mach_port_insert_right 失败,错误信息: %s",mach_error_string(kr));
           exit(1);
    }
    
    //为当前任务设置异常端口
    kr = task_set_exception_ports(mach_task_self(),
                                  EXC_MASK_ALL,
                                  exc_port,
                                  EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES,
                                  THREAD_STATE_NONE);
    if (kr != KERN_SUCCESS) {
          fprintf(stderr, "task_set_exception_ports 失败,错误信息: %s",mach_error_string(kr));
          exit(1);
      }
    
    //创建处理异常消息的线程
    int ret = pthread_create(&thread, TID_NULL, exc_handler_thread, NULL);
    if (ret != 0) {
        fprintf(stderr, "pthread_create");
    }
}
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        setup_exc_port();
        printf("完成异常端口的设置,执行处罚异常的代码\n");
        int *a = NULL;
        *a = 1;
        
        printf("这句话不会被输出");

        
        NSLog(@"Hello, World!");
    }
    return 0;
}
