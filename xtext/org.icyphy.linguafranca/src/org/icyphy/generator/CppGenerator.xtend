/* Generator for Cpp target. */

/*************
 * Copyright (c) 2019, TU Dresden.

 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:

 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.

 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.

 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ***************/
package org.icyphy.generator

import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.LinkedList
import java.util.List
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.icyphy.TimeValue
import org.icyphy.linguaFranca.Action
import org.icyphy.linguaFranca.ActionOrigin
import org.icyphy.linguaFranca.Instantiation
import org.icyphy.linguaFranca.LinguaFrancaPackage
import org.icyphy.linguaFranca.Model
import org.icyphy.linguaFranca.Parameter
import org.icyphy.linguaFranca.Preamble
import org.icyphy.linguaFranca.Reaction
import org.icyphy.linguaFranca.Reactor
import org.icyphy.linguaFranca.StateVar
import org.icyphy.linguaFranca.TimeUnit
import org.icyphy.linguaFranca.Timer
import org.icyphy.linguaFranca.TriggerRef
import org.icyphy.linguaFranca.VarRef
import org.icyphy.linguaFranca.Visibility

import static extension org.icyphy.ASTUtils.*
import java.util.stream.IntStream
import org.icyphy.linguaFranca.Connection
import org.icyphy.linguaFranca.Port
import org.icyphy.ASTUtils
import org.icyphy.scoping.LinguaFrancaGlobalScopeProvider
import com.google.inject.Inject

/** Generator for C++ target.
 * 
 *  @author{Christian Menard <christian.menard@tu-dresden.de}
 *  @author{Edward A. Lee <eal@berkeley.edu>}
 *  @author{Marten Lohstroh <marten@berkeley.edu>}
 */
class CppGenerator extends GeneratorBase {

    @Inject
    LinguaFrancaGlobalScopeProvider scopeProvider;
    

    // Set of acceptable import targets includes only Cpp.
    val acceptableTargetSet = newHashSet('Cpp')

    static public var timeUnitsToCppUnits = #{
        TimeUnit.NSEC -> 'ns',
        TimeUnit.NSECS -> 'ns',
        TimeUnit.USEC -> 'us',
        TimeUnit.USECS -> 'us',
        TimeUnit.MSEC -> 'ms',
        TimeUnit.MSECS -> 'ms',
        TimeUnit.SEC -> 's',
        TimeUnit.SECS -> 's',
        TimeUnit.MIN -> 'min',
        TimeUnit.MINS -> 'min',
        TimeUnit.HOUR -> 'h',
        TimeUnit.HOURS -> 'h',
        TimeUnit.DAY -> 'd',
        TimeUnit.DAYS -> 'd',
        TimeUnit.WEEK -> 'd*7',
        TimeUnit.WEEKS -> 'd*7'
    }

    static public var logLevelsToInts = #{
        "ERROR" -> 1,
        "WARN" -> 2,
        "INFO" -> 3,
        "LOG" -> 3,
        "DEBUG" -> 4
    }

    /** The main Reactor (vs. ReactorInstance, which is in the variable "main"). */
    Reactor mainReactor

    /** Path to the Cpp lib directory (relative to class path)  */
    val libDir = File.separator + "lib" + File.separator + "Cpp"

    def toDir(Resource r) {
        r.toPath.getFilename
    }

    def preambleHeaderFile(Resource r) {
        r.toDir + File.separator + "preamble.hh"
    }

    def preambleSourceFile(Resource r) {
        r.toDir + File.separator + "preamble.cc"
    }

    def headerFile(Reactor r) {
        r.eResource.toDir + File.separator + r.name + ".hh"
    }

    def headerImplFile(Reactor r) {
        r.eResource.toDir + File.separator + r.name + "_impl.hh"
    }

    def sourceFile(Reactor r) {
        r.eResource.toDir + File.separator + r.name + ".cc"
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa,
        IGeneratorContext context) {
        super.doGenerate(resource, fsa, context)
        mainReactor = this.mainDef?.reactorClass.toDefinition

        if (mainReactor === null) {
            // No main reactor. Nothing to do.
            println("WARNING: The given Lingua Franca program does not define a main reactor. Therefore, no code was generated.")
            return
        } else {
            reactors.add(mainReactor)
        }

        fsa.generateFile(filename + File.separator + "main.cc",
            mainReactor.generateMain)
        fsa.generateFile(filename + File.separator + "CMakeLists.txt",
            generateCmake)
        copyFileFromClassPath(libDir + File.separator + "lfutil.hh",
            fsa.getAbsolutePath('''/«filename»/__include__/lfutil.hh'''))
        copyFileFromClassPath(libDir + File.separator + "time_parser.hh",
            fsa.getAbsolutePath('''/«filename»/__include__/time_parser.hh'''))
        copyFileFromClassPath(libDir + File.separator + "3rd-party" + File.separator + "CLI11.hpp",
            fsa.getAbsolutePath('''/«filename»/__include__/CLI/CLI11.hpp'''))

        for (r : reactors) {
            fsa.generateFile(filename + File.separator + r.toDefinition.headerFile,
                r.toDefinition.generateReactorHeader)
            val implFile = r.toDefinition.isGeneric ? r.toDefinition.headerImplFile : r.toDefinition.sourceFile
            fsa.generateFile(filename + File.separator + implFile,
                r.toDefinition.generateReactorSource)
        }

        for (r : this.resources ?: emptyList) {
            fsa.generateFile(filename + File.separator + r.preambleSourceFile,
                r.generatePreambleSource)
            fsa.generateFile(filename + File.separator + r.preambleHeaderFile,
                r.generatePreambleHeader)
        }

        if (!targetNoCompile && !errorsOccurred()) {
            doCompile(fsa)
        } else {
            println("Exiting before invoking target compiler.")
        }
    }

    def extractDir(String path) {
        var result = path
        if (path.startsWith('platform:')) {
            result = result.substring(9)
        }
        if (path.startsWith('file:')) {
            result = result.substring(5)
        }
        var lastSlash = result.lastIndexOf('/')
        if (lastSlash >= 0) {
            result = result.substring(0, lastSlash)
        }
        return result
    }

    def name(Reaction n) {
        var r = n.eContainer as Reactor
        'r' + r.reactions.lastIndexOf(n)
    }
    
    def label(Reaction n) {
        val label = ASTUtils.label(n)
        if (label === null) {
            n.name
        } else {
            label
        }
    }

    def priority(Reaction n) {
        var r = n.eContainer as Reactor
        r.reactions.lastIndexOf(n) + 1
    }

    def declare(Reaction n) '''
        reactor::Reaction «n.name»{"«n.label»", «n.priority», this, [this]() { «n.name»_body(); }};
    '''

    def declareStateVariables(Reactor r) '''
        «FOR s : r.stateVars BEFORE '// state variables\n' AFTER '\n'»
            «s.targetType» «s.name»;
        «ENDFOR»
    '''

    def declareParameters(Reactor r) '''
        «FOR p : r.parameters BEFORE '// parameters\n' AFTER '\n'»
            std::add_const<«p.targetType»>::type «p.name»;
        «ENDFOR»
    '''

    def templateInstance(Instantiation i) '''
        «i.reactorClass.name»«IF i.reactorClass.toDefinition.isGeneric»<«FOR t : i.typeParms SEPARATOR ", "»«t.toText»«ENDFOR»>«ENDIF»
    '''

    // FIXME: Does not support parameter values for widths.
    def declareInstances(Reactor r) '''
        «FOR i : r.instantiations BEFORE '// reactor instantiations\n' AFTER '\n'»
            «IF i.widthSpec !== null»
                std::array<«i.templateInstance», «i.widthSpecification»> «i.name»;
            «ELSE»
                «i.templateInstance» «i.name»;
            «ENDIF»
        «ENDFOR»
    '''

    def declareTimers(Reactor r) '''
        «FOR t : r.timers BEFORE '// timers\n' AFTER '\n'»
            reactor::Timer «t.name»;
        «ENDFOR»
    '''

    def declareReactions(Reactor r) '''
        «FOR n : r.reactions BEFORE '// reactions\n' AFTER '\n'»
            «n.declare»
        «ENDFOR»
    '''
    
    /**
     * If the argument is a multiport with width given as an integer,
     * then return that integer. Otherwise, through an exception for
     * now. FIXME: Support parameters for widths.
     * @param port The port. 
     */
    protected def int multiportWidth(Port port) {
        val spec = multiportWidthSpec(port)
        if (spec !== null && spec.length === 1) {
            if(port.widthSpec.terms.get(0).parameter === null) {
                return port.widthSpec.terms.get(0).width
            }
        }
        throw new Exception("Only multiport widths with literal integer values are supported for now.")
    }
    
    def declarePorts(Reactor r) '''
        «FOR i : r.inputs BEFORE '// input ports\n' AFTER '\n'»
            «IF i.isMultiport»
                std::array<reactor::Input<«i.targetType»>, «calcPortWidth(i)»> «i.name»{{«FOR id : IntStream.range(0, calcPortWidth(i)).toArray SEPARATOR ", "»{"«i.name»_«id»", this}«ENDFOR»}};
            «ELSE»
                reactor::Input<«i.targetType»> «i.name»{"«i.name»", this};
            «ENDIF»
        «ENDFOR»
        «FOR o : r.outputs BEFORE '// output ports\n' AFTER '\n'»
            «IF o.isMultiport»
                std::array<reactor::Output<«o.targetType»>, «calcPortWidth(o)»> «o.name»{{«FOR id : IntStream.range(0, calcPortWidth(o)).toArray SEPARATOR ", "»{"«o.name»_«id»", this}«ENDFOR»}};
            «ELSE»
                reactor::Output<«o.targetType»> «o.name»{"«o.name»", this};
            «ENDIF»
        «ENDFOR»
    '''

    def declareActions(Reactor r) '''
        «FOR a : r.actions BEFORE '// actions\n' AFTER '\n'»
            «a.implementationType» «a.name»;
        «ENDFOR»
        // default actions
        reactor::StartupAction «LinguaFrancaPackage.Literals.TRIGGER_REF__STARTUP.name» {"startup", this};
        reactor::ShutdownAction «LinguaFrancaPackage.Literals.TRIGGER_REF__SHUTDOWN.name» {"shutdown", this};
    '''

    def implementationType(Action a) {
        if (a.origin == ActionOrigin.LOGICAL) {
            '''reactor::LogicalAction<«a.targetType»>'''
        } else {
            '''reactor::PhysicalAction<«a.targetType»>'''
        }
    }

    def declareReactionBodies(Reactor r) '''
        «FOR n : r.reactions BEFORE '// reactions bodies\n' AFTER '\n'»
            void «n.name»_body();
        «ENDFOR»
    '''

    def declareDeadlineHandlers(Reactor r) '''
        «FOR n : r.reactions.filter([Reaction x | x.deadline !== null]) BEFORE '// local deadline handlers\n' AFTER '\n'»
            void «n.name»_deadline_handler();
        «ENDFOR»
    '''

    def implementReactionBodies(Reactor r) '''
        «FOR n : r.reactions SEPARATOR '\n'»
            // reaction «n.label»
            «IF r.isGeneric»«r.templateLine»«ENDIF»
            void «r.templateName»::«n.name»_body() {
              «n.code.toText»
            }
        «ENDFOR»
    '''

    def implementReactionDeadlineHandlers(Reactor r) '''
        «FOR n : r.reactions.filter([Reaction x | x.deadline !== null]) BEFORE '\n' SEPARATOR '\n'»
            // deadline handler for reaction «n.label»
            «IF r.isGeneric»«r.templateLine»«ENDIF»
            void «r.templateName»::«n.name»_deadline_handler() {
              «n.deadline.code.toText»
            }
        «ENDFOR»
    '''

    def includeInstances(Reactor r) '''
        «FOR i : r.instantiations AFTER '\n'»
            #include "«i.reactorClass.toDefinition.headerFile»"
        «ENDFOR»
    '''

    def publicPreamble(Reactor r) {
        val publicPreambles = new LinkedList<Preamble>()
        for (p : r.preambles) {
            if (p.visibility === Visibility.PUBLIC) {
                publicPreambles.add(p)
            }
        }
        '''
            «FOR p : publicPreambles ?: emptyList BEFORE '// public preamble\n' AFTER '\n'»
                «p.code.toText»
            «ENDFOR»
        '''
    }

    def privatePreamble(Reactor r) {
        val privatePreambles = new LinkedList<Preamble>()
        for (p : r.preambles) {
            if (p.visibility === Visibility.PRIVATE) {
                privatePreambles.add(p)
            }
        }
        '''
            «FOR p : privatePreambles ?: emptyList BEFORE '// private preamble\n' AFTER '\n'»
                «p.code.toText»
            «ENDFOR»
        '''
    }

    def declareTrigger(Reaction n, TriggerRef t) {
        if (t instanceof VarRef) {
        	if (t.variable instanceof Port) {
                val p = t.variable as Port
                if (p.widthSpec !== null) {
                    return '''
                        for (unsigned i = 0; i < «t.name».size(); i++) {
                        	«n.name».declare_trigger(&«t.name»[i]);
                        }
                    '''
                }
            }
            // FIXME: support other cases
        }
        return '''«n.name».declare_trigger(&«t.name»);'''
    }

    def declareTriggers(Reaction n) '''
        «FOR t : n.triggers»
            «n.declareTrigger(t)»
        «ENDFOR»
    '''

    def name(VarRef v) {
        if (v.container !== null) {
            '''«v.container.name».«v.variable.name»'''
        } else {
            '''«v.variable.name»'''
        }
    }

    def name(TriggerRef t) {
        if (t instanceof VarRef) {
            t.name
        } else {
            if (t.isShutdown) {
                LinguaFrancaPackage.Literals.TRIGGER_REF__SHUTDOWN.name
            } else if (t.isStartup) {
                LinguaFrancaPackage.Literals.TRIGGER_REF__STARTUP.name
            }
        }
    }
    
    def declareDependency(Reaction n, VarRef v) {
        val p = v.variable as Port
        if (p.widthSpec !== null) {
            return '''
                for (unsigned i = 0; i < «v.name».size(); i++) {
                    «n.name».declare_dependency(&«v.name»[i]);
                }
            '''
        }
        // FIXME: support other cases
        return '''«n.name».declare_dependency(&«v.name»);'''
    }

    def declareDependencies(Reaction n) '''
        «FOR v : n.sources»
            «n.declareDependency(v)»
        «ENDFOR»
    '''

    def declareAntidependency(Reaction n, VarRef v) {
        val p = v.variable as Port
        if (p.widthSpec !== null) {
            return '''
                for (unsigned i = 0; i < «v.name».size(); i++) {
                    «n.name».declare_antidependency(&«v.name»[i]);
                }
            '''
        }
        // FIXME: support other cases
        return '''«n.name».declare_antidependency(&«v.name»);'''
    }

    def declareAntidependencies(Reaction n) '''
        «FOR v : n.effects»
            «IF v.variable instanceof Action»
                «n.name».declare_scheduable_action(&«v.variable.name»);
            «ELSE»
                «n.declareAntidependency(v)»
            «ENDIF»
        «ENDFOR»
    '''

    def declareConstructor(Reactor r) {
        if (r.parameters.length > 0) {
            '''
                «r.name»(const std::string& name,
                    «IF r == mainReactor»reactor::Environment* environment«ELSE»reactor::Reactor* container«ENDIF»,
                    «FOR p : r.parameters SEPARATOR ",\n" AFTER ");"»std::add_lvalue_reference<std::add_const<«p.targetType»>::type>::type «p.name» = «p.targetInitializer»«ENDFOR»
            '''
        } else {
            if (r == mainReactor) {
                '''«r.name»(const std::string& name, reactor::Environment* environment);'''
            } else {
                '''«r.name»(const std::string& name, reactor::Reactor* container);'''
            }
        }
    }

    def templateName(Reactor r) '''«r.name»«IF r.isGeneric»<«FOR t : r.typeParms SEPARATOR ", "»«t.toText»«ENDFOR»>«ENDIF»'''

    def defineConstructor(Reactor r) '''
        «IF r.isGeneric»«r.templateLine»«ENDIF»
        «IF r.parameters.length > 0»
            «r.templateName»::«r.name»(const std::string& name,
                «IF r == mainReactor»reactor::Environment* environment«ELSE»reactor::Reactor* container«ENDIF»,
                «FOR p : r.parameters SEPARATOR ",\n" AFTER ")"»std::add_lvalue_reference<std::add_const<«p.targetType»>::type>::type «p.name»«ENDFOR»
        «ELSE»
            «IF r == mainReactor»
                «r.name»::«r.name»(const std::string& name, reactor::Environment* environment)
            «ELSE»
                «r.name»::«r.name»(const std::string& name, reactor::Reactor* container)
            «ENDIF»
        «ENDIF»
          : reactor::Reactor(name, «IF r == mainReactor»environment«ELSE»container«ENDIF»)
          «r.initializeParameters»
          «r.initializeStateVariables»
          «r.initializeInstances»
          «r.initializeActions»
          «r.initializeTimers»
        {}
    '''

    def String getTargetInitializer(StateVar state) {
        '''«FOR init : state.initializerList SEPARATOR ", "»«init»«ENDFOR»'''
    }

    def private String getTargetInitializerHelper(Parameter param,
        List<String> list) {
        if (list.size == 0) {
            param.reportError("Parameters must have a default value!")
        } else if (list.size == 1) {
            return list.get(0)
        } else {
            '''{«FOR init : list SEPARATOR ", "»«init»«ENDFOR»}'''
        }
    }

    def String getTargetInitializer(Parameter param) {
        return getTargetInitializerHelper(param, param.initializerList)
    }

    def String getTargetInitializer(Parameter param, Instantiation i) {
        return getTargetInitializerHelper(param, param.getInitializerList(i))
    }

    def initializeParameters(Reactor r) '''
        «FOR p : r.parameters BEFORE "// parameters\n"»
            , «p.name»(«p.name»)
        «ENDFOR»
    '''

    def initializeStateVariables(Reactor r) '''
        «FOR s : r.stateVars.filter[s | s.isInitialized] BEFORE "// state variables\n"»
            , «s.name»{«s.targetInitializer»} // «s.isInitialized»
        «ENDFOR»
    '''

    def initializerList(Instantiation i) '''
        {"«i.name»", this«FOR p : i.reactorClass.toDefinition.parameters», «p.getTargetInitializer(i)»«ENDFOR»}
    '''

    def initializerList(Instantiation i, Integer id) '''
        {"«i.name»_«id»", this«FOR p : i.reactorClass.toDefinition.parameters», «IF p.name == "instance"»«id»«ELSE»«p.getTargetInitializer(i)»«ENDIF»«ENDFOR»}
    '''

    // FIXME: Does not support parameter values for widths.
    def initializeInstances(Reactor r) '''
        «FOR i : r.instantiations BEFORE "// reactor instantiations \n"»
            «IF i.widthSpec !== null»
                , «i.name»{{«FOR id : IntStream.range(0, i.widthSpecification).toArray SEPARATOR ", "»«i.initializerList(id)»«ENDFOR»}}
            «ELSE»
                , «i.name»«i.initializerList»
            «ENDIF»
        «ENDFOR»
    '''

    def initializeActions(Reactor r) '''
        «FOR a : r.actions BEFORE '// actions\n' AFTER '\n'»
            «a.initialize»
        «ENDFOR»
    '''

    def initializeTimers(Reactor r) '''
        «FOR t : r.timers BEFORE "// timers\n"»
            «t.initialize»
        «ENDFOR»
    '''

    def initialize(Timer t) {
        var String period = "reactor::Duration::zero()"
        var String offset = "reactor::Duration::zero()"
        if (t.offset !== null) {
            offset = '''«t.offset.targetTime»'''
        }
        if (t.period !== null) {
            period = '''«t.period.targetTime»'''
        }
        ''', «t.name»{"«t.name»", this, «period», «offset»}'''
    }

    def initialize(Action a) {
        if (a.origin == ActionOrigin.LOGICAL) {
            if (a.minInterArrival !== null || a.drop == true) {
                a.reportError(
                    "minInterArrival and tail drop are not supported for logical actions!");
            } else if (a.minDelay !== null) {
                ''', «a.name»{"«a.name»", this, «a.minDelay.targetTime»}'''
            } else {
                ''', «a.name»{"«a.name»", this}'''
            }
        } else {
            if (a.minDelay !== null || a.minInterArrival !== null || a.drop == true) {
                a.reportError(
                    "minDelay, minInterArrival and tail drop are not supported for physical actions!");
            } else {
                ''', «a.name»{"«a.name»", this}'''
            }
        }
    }

    def assembleReaction(Reactor r, Reaction n) '''
        // «n.name»
        «n.declareTriggers»
        «n.declareDependencies»
        «n.declareAntidependencies»
        «IF n.deadline !== null»
            «n.name».set_deadline(«n.deadline.delay.targetTime», [this]() { «n.name»_deadline_handler(); });
        «ENDIF»
    '''

    def generatePreambleHeader(Resource r) '''
        «r.header»
        
        #pragma once
        
        #include <vector>
        #include <array>

        #include "reactor-cpp/reactor-cpp.hh"
        «FOR i : scopeProvider?.getImportedResources(r) ?: emptyList BEFORE "// include the preambles from imported resource \n"»
            #include "«i.preambleHeaderFile»"
        «ENDFOR»
        
        «FOR p : r.allContents.toIterable.filter(Model).iterator().next().preambles»
            «IF p.visibility === Visibility.PUBLIC»«p.code.toText»«ENDIF»
        «ENDFOR»
    '''

    def generatePreambleSource(Resource r) '''
        «r.header»
        
        #include "reactor-cpp/reactor-cpp.hh"
        
        #include "«r.preambleHeaderFile»"
        
        using namespace std::chrono_literals;
        using namespace reactor::operators;
        
        «FOR p : r.allContents.toIterable.filter(Model).iterator().next().preambles»
            «IF p.visibility === Visibility.PRIVATE»«p.code.toText»«ENDIF»
        «ENDFOR»
    '''

    def generateReactorHeader(Reactor r) '''
        «r.eResource.header»
        
        #pragma once
        
        #include "reactor-cpp/reactor-cpp.hh"
        
        #include "«r.eResource.preambleHeaderFile»"
        
        «r.includeInstances»
        «r.publicPreamble»
        
        «IF r.isGeneric»«r.templateLine»«ENDIF»
        class «r.name» : public reactor::Reactor {
         private:
          «r.declareParameters»
          «r.declareStateVariables»
          «r.declareInstances»
          «r.declareTimers»
          «r.declareActions»
          «r.declareReactions»
          «r.declareReactionBodies»
          «r.declareDeadlineHandlers»
         public:
          «r.declarePorts»
          «r.declareConstructor»
          
          void assemble() override;
        };
        «IF r.isGeneric»
        
        #include "«r.headerImplFile»"
        «ENDIF»
    '''

    def templateLine(Reactor r) '''
        template<«FOR t: r.typeParms SEPARATOR ", "»class «t.toText»«ENDFOR»>
    '''
    
    /**
     * Calculate the width of a multiport.
     * FIXME: This currently
     * throws an exception if the width depends on a parameter value.
     * If the width depends on a parameter value, then this method
     * will need to determine that parameter for each instance, not
     * just class definition of the containing reactor.
     */
    def int calcPortWidth(Port port) {
        val result = port.widthSpec.width
        if (result < 0) {
            throw new Exception("Only multiport widths with literal integer values are supported for now.")
        }
        return result
    }

    def generate(Connection c) {
        val result = new StringBuffer()
        var leftPort = c.leftPorts.get(0)
        var leftPortCount = 1
        // The index will go from zero to mulitportWidth - 1.
        var leftPortIndex = 0
        // FIXME: Support parameterized widths and check for matching widths with parallel connections.
        var leftWidth = leftPort.portWidth(c)
        var leftContainer = leftPort.container
        var rightPortCount = 0
        for (rightPort : c.rightPorts) {
            rightPortCount++
            var rightPortIndex = 0
            val rightContainer = rightPort.container
            val rightWidth = rightPort.portWidth(c)
            while (rightPortIndex < rightWidth) {
                // Figure out how many bindings to do.
                var remainingRightPorts = rightWidth - rightPortIndex
                var remainingLeftPorts = leftWidth - leftPortIndex
                var min = (remainingRightPorts < remainingLeftPorts)?
                        remainingRightPorts : remainingLeftPorts
                // If the right or left port is a port in a bank of reactors,
                // then we need to construct the index for the bank.
                // Start with the right port.
                var rightContainerRef = ''
                var rightPortArrayIndex = ''
                if (rightContainer !== null) {
                    if (rightContainer.widthSpec !== null) {
                        // The right port is within a bank of reactors.
                        var rightMultiportWidth = 1
                        if ((rightPort.variable as Port).widthSpec !== null) {
                            // The right port is also a multiport.
                            rightMultiportWidth = calcPortWidth(rightPort.variable as Port)
                            rightPortArrayIndex = '''[(«rightPortIndex» + i) % «rightMultiportWidth»]'''
                        }
                        rightContainerRef = '''«rightContainer.name»[(«rightPortIndex» + i) / «rightMultiportWidth»].'''
                    } else {
                        rightContainerRef = '''«rightContainer.name».'''
                        if ((rightPort.variable as Port).widthSpec !== null) {
                            rightPortArrayIndex = '''[«rightPortIndex» + i]'''
                        }
                    }
                } else if ((rightPort.variable as Port).widthSpec !== null) {
                    // The right port is not within a bank of reactors but is a multiport.
                    rightPortArrayIndex = '''[«rightPortIndex» + i]'''
                }
                // Next, do the left port.
                var leftContainerRef = ''
                var leftPortArrayIndex = ''
                if (leftContainer !== null) {
                    if (leftContainer.widthSpec !== null) {
                        // The left port is within a bank of reactors.
                        var leftMultiportWidth = 1
                        if ((leftPort.variable as Port).widthSpec !== null) {
                            // The left port is also a multiport.
                            // FIXME: Does not support parameter values for widths.
                            leftMultiportWidth = calcPortWidth(leftPort.variable as Port)
                            leftPortArrayIndex = '''[(«leftPortIndex» + i) % «leftMultiportWidth»]'''
                        }
                        leftContainerRef = '''«leftContainer.name»[(«leftPortIndex» + i) / «leftMultiportWidth»].'''
                    } else {
                        leftContainerRef = '''«leftContainer.name».'''
                        if ((leftPort.variable as Port).widthSpec !== null) {
                            leftPortArrayIndex = '''[«leftPortIndex» + i]'''
                        }
                    }
                } else if ((leftPort.variable as Port).widthSpec !== null) {
                    // The left port is not within a bank of reactors but is a multiport.
                    leftPortArrayIndex = '''[«leftPortIndex» + i]'''
                }
                result.append('''
                    for (unsigned i = 0; i < «min»; i++) {
                        «leftContainerRef»«leftPort.variable.name»«leftPortArrayIndex»
                                .bind_to(&«rightContainerRef»«rightPort.variable.name»«rightPortArrayIndex»);
                    }
                ''')
                rightPortIndex += min
                leftPortIndex += min
                if (leftPortIndex == leftPort.portWidth(c)) {
                    if (leftPortCount < c.leftPorts.length) {
                        // Get the next left port. Here we rely on the validator to
                        // have checked that the connection is balanced, which it does only
                        // when widths are given as literal constants.
                        leftPort = c.leftPorts.get(leftPortCount++)
                        leftWidth = leftPort.portWidth(c)
                        leftPortIndex = 0
                        leftContainer = leftPort.container
                    } else {
                        // We have run out of left ports.
                        // If the connection is a broadcast connection,
                        // then start over.
                        if (c.isIterated) {
                            leftPort = c.leftPorts.get(0)
                            leftPortCount = 1
                            leftWidth = leftPort.portWidth(c)
                            leftPortIndex = 0
                            leftContainer = leftPort.container
                        } else if (rightPortCount < c.rightPorts.length || rightPortIndex < rightWidth - 1) {
                            c.reportWarning("More right ports than left ports. Some right ports will be unconnected.")
                        }
                    }
                }
            }
        }
        return result.toString
    }

    def generateReactorSource(Reactor r) '''
        «r.eResource.header»

        «IF !r.isGeneric»#include "reactor-cpp/reactor-cpp.hh"«ENDIF»

        using namespace std::chrono_literals;
        using namespace reactor::operators;

        «IF !r.isGeneric»#include "«r.headerFile»"«ENDIF»
        #include "lfutil.hh"

        «r.privatePreamble»

        «r.defineConstructor»

        «r.defineAssembleMethod»

        «r.implementReactionBodies»
        «r.implementReactionDeadlineHandlers»
    '''
    
    def defineAssembleMethod(Reactor r) '''
        «IF r.isGeneric»«r.templateLine»«ENDIF»
        void «r.templateName»::assemble() {
          «FOR n : r.reactions»
             «r.assembleReaction(n)»
          «ENDFOR»
          «FOR c : r.connections BEFORE "  // connections\n"»
             «c.generate»
          «ENDFOR»
        }
    '''

    def header(Resource r) '''
        /*
         * This file was autogenerated by the Lingua Franca Compiler
         *
         * Source: «r.URI»
         * Date: «new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())»
         */
    '''

    def generateMain(Reactor main) '''
        «resource.header»
        
        #include <chrono>        
        #include <thread>
        #include <memory>
        
        #include "reactor-cpp/reactor-cpp.hh"
        
        using namespace std::chrono_literals;
        using namespace reactor::operators;
        
        #include "time_parser.hh"
        
        #include "CLI/CLI11.hpp"
        
        #include "«main.headerFile»"
        
        class Timeout : public reactor::Reactor {
         private:
          reactor::Timer timer;
        
          reactor::Reaction r_timer{"r_timer", 1, this,
                                    [this]() { environment()->sync_shutdown(); }};
        
         public:
          Timeout(const std::string& name, reactor::Environment* env, reactor::Duration timeout)
              : reactor::Reactor(name, env)
              , timer{"timer", this, reactor::Duration::zero(), timeout} {}
        
          void assemble() override { r_timer.declare_trigger(&timer); }
        };
        
        int main(int argc, char **argv) {
          CLI::App app("«filename» Reactor Program");
          
          unsigned threads = «IF targetThreads != 0»«Integer.toString(targetThreads)»«ELSE»std::thread::hardware_concurrency()«ENDIF»;
          app.add_option("-t,--threads", threads, "the number of worker threads used by the scheduler", true);
        
          reactor::Duration timeout = «IF targetTimeout > 0»«targetTimeout»«timeUnitsToCppUnits.get(targetTimeoutUnit)»«ELSE»reactor::Duration::zero()«ENDIF»;
          auto opt_timeout = app.add_option("-o,--timeout", timeout, "Time after which the execution is aborted.");
        
          opt_timeout->check([](const std::string& val){ return validate_time_string(val); });
          opt_timeout->type_name("'FLOAT UNIT'");
          opt_timeout->default_str(time_to_quoted_string(timeout));
        
          bool fast{«targetFast»};
          app.add_flag("-f,--fast", fast, "Allow logical time to run faster than physical time.");
        
          bool keepalive{«targetKeepalive»};
          app.add_flag("-k,--keepalive", keepalive, "Continue execution even when there are no events to process.");
          «FOR p : mainReactor.parameters»

            «p.targetType» «p.name» = «p.targetInitializer»;
            auto opt_«p.name» = app.add_option("--«p.name»", «p.name», "The «p.name» parameter passed to the main reactor «mainReactor.name».");
            «IF p.inferredType.isTime»
                opt_«p.name»->check([](const std::string& val){ return validate_time_string(val); });
                opt_«p.name»->type_name("'FLOAT UNIT'");
                opt_«p.name»->default_str(time_to_quoted_string(«p.name»));
            «ENDIF»
          «ENDFOR»
        
          app.get_formatter()->column_width(50);
        
          CLI11_PARSE(app, argc, argv);
        
          reactor::Environment e{threads, keepalive, fast};
        
          // instantiate the main reactor
          «main.name» main{"«main.name»", &e«FOR p : mainReactor.parameters BEFORE ", " SEPARATOR ", "»«p.name»«ENDFOR»};
          
          // optionally instantiate the timeout reactor
          std::unique_ptr<Timeout> t{nullptr};
          if (timeout != reactor::Duration::zero()) {
            t = std::make_unique<Timeout>("Timeout", &e, timeout);
          }
        
          // execute the reactor program
          e.assemble();
          auto thread = e.startup();
          thread.join();
        
          return 0;
        }
    '''

    def generateCmake() '''
        cmake_minimum_required(VERSION 3.5)
        project(«filename» VERSION 1.0.0 LANGUAGES CXX)
        
        # require C++ 17
        set(CMAKE_CXX_STANDARD 17)
        set(CMAKE_CXX_STANDARD_REQUIRED ON)
        set(CMAKE_CXX_EXTENSIONS OFF)
        
        include(${CMAKE_ROOT}/Modules/ExternalProject.cmake)
        include(GNUInstallDirs)
        
        set(DEFAULT_BUILD_TYPE «IF targetBuildType === null»"Release"«ELSE»"«targetBuildType»"«ENDIF»)
        if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
          set(CMAKE_BUILD_TYPE "${DEFAULT_BUILD_TYPE}" CACHE STRING "Choose the type of build." FORCE)
        endif()
        
        if(NOT REACTOR_CPP_BUILD_DIR)
          set(REACTOR_CPP_BUILD_DIR "" CACHE STRING "Choose the directory to build reactor-cpp in." FORCE)
        endif()
        
        ExternalProject_Add(
          dep-reactor-cpp
          PREFIX "${REACTOR_CPP_BUILD_DIR}"
          GIT_REPOSITORY "https://github.com/tud-ccc/reactor-cpp.git"
          GIT_TAG "2aae163e612feb697a29cd5383e5736e7d12b3a3"
          CMAKE_ARGS
            -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX}
            -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DREACTOR_CPP_VALIDATE=«IF targetNoRuntimeValidation»OFF«ELSE»ON«ENDIF»
            -DREACTOR_CPP_TRACE=«IF targetTracing»ON«ELSE»OFF«ENDIF»
            «IF targetLoggingLevel !== null»-DREACTOR_CPP_LOG_LEVEL=«logLevelsToInts.get(targetLoggingLevel)»«ENDIF»
        )
        
        set(REACTOR_CPP_LIB_NAME "${CMAKE_SHARED_LIBRARY_PREFIX}reactor-cpp${CMAKE_SHARED_LIBRARY_SUFFIX}")
        set(REACTOR_CPP_LIB_DIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
        
        add_library(reactor-cpp SHARED IMPORTED)
        add_dependencies(reactor-cpp dep-reactor-cpp)
        set_target_properties(reactor-cpp PROPERTIES IMPORTED_LOCATION "${REACTOR_CPP_LIB_DIR}/${REACTOR_CPP_LIB_NAME}")
        
        if (APPLE)
          set(CMAKE_INSTALL_RPATH "@executable_path/../lib")
        else ()
          set(CMAKE_INSTALL_RPATH "${REACTOR_CPP_LIB_DIR}")
        endif ()
        set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
        
        add_executable(«filename»
          main.cc
          «FOR r : reactors»
              «IF !r.toDefinition.isGeneric»«r.toDefinition.sourceFile»«ENDIF»
          «ENDFOR»
          «FOR r : resources»
              «r.preambleSourceFile»
          «ENDFOR»
        )
        target_include_directories(«filename» PUBLIC
            "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}"
            "${PROJECT_SOURCE_DIR}"
            "${PROJECT_SOURCE_DIR}/__include__"
        )
        target_link_libraries(«filename» reactor-cpp)
        
        install(TARGETS «filename» RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
        
        «IF targetCmakeInclude !== null»
            include("«directory»«File.separator»«targetCmakeInclude»")
        «ENDIF»
    '''

    def void doCompile(IFileSystemAccess2 fsa) {
        val srcGenPath = fsa.getAbsolutePath('/')
        val rootPath = srcGenPath.substring(0, srcGenPath.length() - "/src-gen".length())

        val srcPath = fsa.getAbsolutePath('''«filename»/''')
        val installPath = rootPath
        val buildPath = '''«rootPath»/build/«filename»'''
        val reactorCppPath = '''«rootPath»/build/reactor-cpp'''
        
        var buildDir = new File(buildPath)
        if (!buildDir.exists()) buildDir.mkdirs()

        val makeBuilder = createCommand("make", #[
            '''-j«Runtime.getRuntime().availableProcessors()»''',
            "install"])
        val cmakeBuilder = createCommand("cmake", #[
            '''-DCMAKE_INSTALL_PREFIX=«installPath»''',
            '''-DREACTOR_CPP_BUILD_DIR=«reactorCppPath»''',
            srcPath])
        if (makeBuilder === null || cmakeBuilder === null) {
            return
        }

        // prepare cmake
        cmakeBuilder.directory(buildDir)
        if (targetCompiler !== null) {
            val cmakeEnv = cmakeBuilder.environment();
            cmakeEnv.put("CXX", targetCompiler);
        }
        
        // run cmake
        val cmakeReturnCode = cmakeBuilder.execute();

        if (cmakeReturnCode == 0) {
            // If cmake succeeded, prepare and run make
            makeBuilder.directory(buildDir)
            val makeReturnCode = makeBuilder.execute()

            if (makeReturnCode == 0) {
                println("SUCCESS (compiling generated C++ code)")
                println('''Generated source code is in «srcPath»''')
                println('''Compiled binary is in «installPath»/bin/«filename»''')
            } else {
                reportError('''make failed with error code «makeReturnCode»''')
            }
        } else {
            reportError('''cmake failed with error code «cmakeReturnCode»''')
        }
    }

    // //////////////////////////////////////////////
    // // Protected methods
    /** Return a set of targets that are acceptable to this generator.
     *  Imported files that are Lingua Franca files must specify targets
     *  in this set or an error message will be reported and the import
     *  will be ignored. The returned set is a set of case-insensitive
     *  strings specifying target names.
     */
    override acceptableTargets() {
        acceptableTargetSet
    }

    /**
     * Generate code for the body of a reaction that takes an input and
     * schedules an action with the value of that input.
     * @param the action to schedule
     * @param the port to read from
     */
    override generateDelayBody(Action action, VarRef port) {
        // Since we cannot easily decide whether a given type evaluates
        // to void, we leave this job to the target compiler, by calling
        // the template function below.
        '''
            // delay body for «action.name»
            lfutil::after_delay(&«action.name», &«port.name»);
        '''
    }

    /**
     * Generate code for the body of a reaction that is triggered by the
     * given action and writes its value to the given port.
     * @param the action that triggers the reaction
     * @param the port to write to
     */
    override generateForwardBody(Action action, VarRef port) // Since we cannot easily decide whether a given type evaluates
    // to void, we leave this job to the target compiler, by calling
    // the template function below.
    '''
        // forward body for «action.name»
        lfutil::after_forward(&«action.name», &«port.name»);
    '''

    /** Given a representation of time that may possibly include units,
     *  return a string that C++ recognizes as a time value.
     * 
     *  @param time A TimeValue that represents a time.
     *  @return A string, such as "100ms" for 100 milliseconds.
     */
    override timeInTargetLanguage(TimeValue time) {
        if (time !== null) {
            if (time.unit != TimeUnit.NONE) {
                return time.time.toString() + timeUnitsToCppUnits.get(time.unit)
            } else if (time.time == 0) {
                return '''reactor::Duration::zero()'''
            } else {
                return '''/* «reportError("Valid times must be zero or have a unit!")» */'''
            }
        }
        return '''/* «reportError("Expected a time")» */'''
    }

    override getTargetTimeType() '''reactor::Duration'''

    override getTargetUndefinedType() '''/* «reportError("undefined type")» */'''

    // this override changes the undefined type for actions to void
    override getTargetType(Action a) {
        val inferred = a.inferredType;
        if (inferred.isUndefined) {
            return "void"
        } else {
            return inferred.targetType
        }
    }

    override getTargetFixedSizeListType(String baseType,
        Integer size) '''std::array<«baseType», «size.toString»>'''

    override getTargetVariableSizeListType(
        String baseType) '''std::vector<«baseType»>'''
        
    override supportsGenerics() {
        true
    }
    
    override String generateDelayGeneric()
        '''T'''
    
}
