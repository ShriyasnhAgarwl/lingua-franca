package org.icyphy.scoping;

import org.eclipse.xtext.resource.containers.StateBasedContainerManager;
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.IResourceDescription
import java.util.List
import org.eclipse.xtext.resource.containers.DescriptionAddingContainer
import org.eclipse.xtext.resource.IContainer
import java.util.Collections
import org.eclipse.xtext.resource.containers.ProjectDescriptionBasedContainerManager
import com.google.inject.Inject
import java.util.ArrayList

//import org.eclipse.xtext.resource.containers.IAllContainersState

class LinguaFrancaContainerManager extends StateBasedContainerManager {

    @Inject
	ProjectDescriptionBasedContainerManager delegate;
	
	//@Inject
	//LinguaFrancaStateManager.Provider stateProvider;
	
	override
	List<IContainer> getVisibleContainers(IResourceDescription desc, IResourceDescriptions resourceDescriptions) {
		if (delegate.shouldUseProjectDescriptionBasedContainers(resourceDescriptions)) {
			return delegate.getVisibleContainers(desc, resourceDescriptions);
		}
		val root = internalGetContainerHandle(desc, resourceDescriptions);
		if (root === null) {
			return Collections.emptyList();
		}
		val handles = getState(resourceDescriptions).getVisibleContainerHandles(root);
		val result = getVisibleContainers(handles, resourceDescriptions);
		if (!result.isEmpty()) {
			var first = result.get(0);
			if (!first.hasResourceDescription(desc.getURI())) {
				first = new DescriptionAddingContainer(desc, first);
				result.set(0, first);
			}
		}

		
		try{
		    val LF_CLASSPATH = System.getenv("LF_CLASSPATH")
		    val paths = LF_CLASSPATH.split(System.getProperty("path.separator"));
		    var path_list = new ArrayList<String>(paths.length)
		    Collections.addAll ( path_list, paths)
		    System.out.println("Reading Lingua Franca classpath: " + paths.toString)
		    System.out.println("Reading resource descriptions : " + resourceDescriptions.toString)
		    result.addAll(super.getVisibleContainers(path_list, resourceDescriptions))
		}
		catch (Exception e)
		{
			System.out.println("Error: " + e.message)
		}
		
		System.out.println("Returning containers : " + result.toString)
		return result;
	}


}